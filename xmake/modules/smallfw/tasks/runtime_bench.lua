import("core.base.json")
import("core.base.option")
import("lib.detect.find_program")
import("smallfw.task_helpers")

local function _positive_integer_option(name, default_value)
    local raw = option.get(name)
    if raw == nil or raw == "" then
        return default_value
    end

    local value = tonumber(raw)
    assert(value ~= nil and value >= 1 and math.floor(value) == value,
        string.format("option --%s must be a positive integer", name))
    return value
end

local function _nonnegative_integer_option(name, default_value)
    local raw = option.get(name)
    if raw == nil or raw == "" then
        return default_value
    end

    local value = tonumber(raw)
    assert(value ~= nil and value >= 0 and math.floor(value) == value,
        string.format("option --%s must be a non-negative integer", name))
    return value
end

local function _string_option(name, default_value)
    local value = option.get(name)
    if value == nil or value == "" then
        return default_value
    end
    return value
end

local function _enum_option(name, default_value, allowed)
    local value = _string_option(name, default_value)
    for _, entry in ipairs(allowed) do
        if value == entry then
            return value
        end
    end
    raise(string.format("option --%s must be one of: %s", name, table.concat(allowed, ", ")))
end

local function _append_compile_and_link_flags(args, compile_flags, link_flags)
    if #compile_flags > 0 then
        local joined = table.concat(compile_flags, " ")
        table.insert(args, "--cflags=" .. joined)
        table.insert(args, "--cxflags=" .. joined)
        table.insert(args, "--mflags=" .. joined)
        table.insert(args, "--mxflags=" .. joined)
    end
    if #link_flags > 0 then
        table.insert(args, "--ldflags=" .. table.concat(link_flags, " "))
    end
end

local function _configure_args(builddir, pgo_mode, profdata)
    local extra_args = {}
    if option.get("analysis-symbols") == nil or option.get("analysis-symbols") == "" then
        table.insert(extra_args, "--analysis-symbols=y")
    end
    local args = task_helpers.collect_configure_args(extra_args, {
        mode = _string_option("mode", "release"),
        plat = _string_option("plat", "linux"),
        arch = _string_option("arch", "x86_64"),
        builddir = builddir,
    })
    local compile_flags = {}
    local link_flags = {}

    if pgo_mode == "gen" then
        table.insert(compile_flags, "-fprofile-instr-generate")
        table.insert(link_flags, "-fprofile-instr-generate")
        table.insert(link_flags, task_helpers.profile_runtime_library())
    elseif pgo_mode == "use" then
        assert(profdata ~= nil and profdata ~= "", "PGO use mode requires a merged profdata file")
        table.insert(compile_flags, "-fprofile-instr-use=" .. path.absolute(profdata))
        table.insert(compile_flags, "-Wno-profile-instr-unprofiled")
        table.insert(compile_flags, "-Wno-profile-instr-missing")
    end

    _append_compile_and_link_flags(args, compile_flags, link_flags)
    return args
end

local function _bench_args(case_name, iters)
    local args = {"--case", case_name}
    if iters ~= nil then
        table.insert(args, "--iters")
        table.insert(args, tostring(iters))
    end
    return args
end

local function _parse_bench_output(text)
    local results = {}
    for line in (text or ""):gmatch("[^\r\n]+") do
        local name, iters, total_ns, ns_per = line:match("^([^,]+),(%d+),(%d+),([%d%.]+)$")
        if name ~= nil then
            table.insert(results, {
                name = name,
                iters = assert(tonumber(iters)),
                total_ns = assert(tonumber(total_ns)),
                ns_per = assert(tonumber(ns_per)),
            })
        end
    end
    return results
end

local function _sorted_copy(values)
    local copy = {}
    for index, value in ipairs(values) do
        copy[index] = value
    end
    table.sort(copy)
    return copy
end

local function _mean(values)
    local sum = 0.0
    for _, value in ipairs(values) do
        sum = sum + value
    end
    return (#values > 0) and (sum / #values) or 0.0
end

local function _median(values)
    if #values == 0 then
        return 0.0
    end
    local sorted = _sorted_copy(values)
    local middle = math.floor(#sorted / 2) + 1
    if (#sorted % 2) == 1 then
        return sorted[middle]
    end
    return (sorted[middle - 1] + sorted[middle]) / 2.0
end

local function _stdev(values, mean_value)
    if #values <= 1 then
        return 0.0
    end
    local accum = 0.0
    for _, value in ipairs(values) do
        local delta = value - mean_value
        accum = accum + (delta * delta)
    end
    return math.sqrt(accum / #values)
end

local function _append_csv_row(lines, sample_index, result)
    table.insert(lines, string.format("%d,%s,%d,%d,%.6f",
        sample_index, result.name, result.iters, result.total_ns, result.ns_per))
end

local function _summarize(samples)
    local grouped = {}
    local ordered_names = {}

    for _, sample in ipairs(samples) do
        for _, result in ipairs(sample.results) do
            local bucket = grouped[result.name]
            if bucket == nil then
                bucket = {
                    name = result.name,
                    iters = result.iters,
                    ns_per_values = {},
                    total_ns_values = {},
                }
                grouped[result.name] = bucket
                table.insert(ordered_names, result.name)
            end
            table.insert(bucket.ns_per_values, result.ns_per)
            table.insert(bucket.total_ns_values, result.total_ns)
        end
    end

    local summary = {}
    for _, name in ipairs(ordered_names) do
        local bucket = grouped[name]
        local mean_value = _mean(bucket.ns_per_values)
        local total_sorted = _sorted_copy(bucket.total_ns_values)
        local ns_sorted = _sorted_copy(bucket.ns_per_values)
        table.insert(summary, {
            name = bucket.name,
            iters = bucket.iters,
            samples = #bucket.ns_per_values,
            mean_ns_per = mean_value,
            median_ns_per = _median(bucket.ns_per_values),
            min_ns_per = ns_sorted[1] or 0.0,
            max_ns_per = ns_sorted[#ns_sorted] or 0.0,
            stdev_ns_per = _stdev(bucket.ns_per_values, mean_value),
            best_total_ns = total_sorted[1] or 0,
            worst_total_ns = total_sorted[#total_sorted] or 0,
        })
    end
    return summary
end

local function _capture_optional(program, args)
    local ok, output = task_helpers.try_command_output(program, args)
    if not ok then
        return nil
    end
    return task_helpers.trim(output)
end

local function _perf_usable(program)
    local ok = task_helpers.try_command_output(program, {
        "stat",
        "-o", "/dev/null",
        "/bin/true",
    })
    return ok
end

local function _perf_branch_stack_usable(program)
    local probe = path.join(os.tmpdir(), string.format("smallfw-bolt-%d.data", os.mclock()))
    local ok = task_helpers.try_command_output(program, {
        "record",
        "-o", probe,
        "-e", "cycles:u",
        "-j", "any,u",
        "/bin/true",
    })
    os.tryrm(probe)
    return ok
end

local function _binary_build_id(binary)
    local readelf = find_program("readelf") or find_program("llvm-readelf")
    if readelf == nil then
        return nil
    end

    local ok, output = task_helpers.try_command_output(readelf, {"-n", binary})
    if not ok then
        return nil
    end
    return (output or ""):match("Build ID:%s*([0-9a-fA-F]+)")
end

local function _perf_data_has_binary_samples(program, perf_data, binary)
    local ok, output = task_helpers.try_command_output(program, {"buildid-list", "-i", perf_data})
    if not ok then
        return false
    end

    local build_id = _binary_build_id(binary)
    for line in (output or ""):gmatch("[^\r\n]+") do
        if build_id ~= nil and line:find(build_id, 1, true) then
            return true
        end
        if line:find(path.absolute(binary), 1, true) or line:match(path.filename(binary) .. "$") then
            return true
        end
    end
    return false
end

local function _bolt_record_iteration_candidates(iters)
    local seen = {}
    local values = {}
    local function _push(value)
        if value ~= nil and value >= 1 and not seen[value] then
            seen[value] = true
            table.insert(values, value)
        end
    end

    _push(iters)
    _push(math.max(iters or 0, 50000))
    _push(math.max(iters or 0, 250000))
    _push(math.max(iters or 0, 1000000))
    return values
end

local function _merge_profraws(profdir)
    local profraws = os.files(path.join(profdir, "*.profraw"))
    local llvm_profdata = nil
    local profdata = nil
    local args = nil

    if #profraws == 0 then
        raise("No .profraw files were generated under " .. profdir)
    end

    table.sort(profraws)
    llvm_profdata = task_helpers.llvm_profdata_program()
    profdata = path.join(profdir, "merged.profdata")
    args = {"merge", "-sparse"}
    for _, profraw in ipairs(profraws) do
        table.insert(args, profraw)
    end
    table.insert(args, "-o")
    table.insert(args, profdata)
    os.execv(llvm_profdata, args)
    return profdata
end

local function _run_pgo_training(run_dir, mode_name, case_name, iters)
    local pgo_dir = path.join(run_dir, "pgo")
    local builddir = path.join(pgo_dir, "build")
    local configure_log = path.join(pgo_dir, "configure.log")
    local build_log = path.join(pgo_dir, "build.log")
    local train_log = path.join(pgo_dir, "train.csv")
    local prof_pattern = path.join(path.absolute(pgo_dir), "%m-%p.profraw")
    local runtime_bench = path.absolute(task_helpers.target_binary(builddir, "runtime-bench", mode_name))

    os.mkdir(pgo_dir)

    task_helpers.write_command_output(configure_log, "xmake", _configure_args(builddir, "gen"))
    task_helpers.write_command_output(build_log, "xmake", {"b", "runtime-bench"}, {
        envs = {SMALLFW_SKIP_RELEASE_CLANG_TIDY = "1"},
    })

    local train_program, train_args = task_helpers.pinned_command(runtime_bench, _bench_args(case_name, iters))
    task_helpers.write_command_output(train_log, train_program, train_args, {
        envs = {LLVM_PROFILE_FILE = prof_pattern},
    })

    return _merge_profraws(pgo_dir), {
        pgo_configure_log = path.absolute(configure_log),
        pgo_build_log = path.absolute(build_log),
        pgo_train_log = path.absolute(train_log),
        pgo_profdata = path.absolute(path.join(pgo_dir, "merged.profdata")),
    }
end

local function _bolt_optimize_binary(run_dir, binary, case_name, iters)
    local bolt_dir = path.join(run_dir, "bolt")
    local perf = task_helpers.find_required_program("perf", "perf not found")
    local perf2bolt = task_helpers.perf2bolt_program()
    local llvm_bolt = task_helpers.llvm_bolt_program()
    local perf_data = path.absolute(path.join(bolt_dir, "perf.data"))
    local perf_record_log = path.join(bolt_dir, "perf.record.log")
    local perf2bolt_log = path.join(bolt_dir, "perf2bolt.log")
    local llvm_bolt_log = path.join(bolt_dir, "llvm-bolt.log")
    local fdata = path.join(bolt_dir, "runtime-bench.fdata")
    local output_binary = path.join(bolt_dir, path.filename(binary) .. ".bolt")
    local use_lbr = _perf_branch_stack_usable(perf)

    assert(_perf_usable(perf), "perf is installed, but perf events are not permitted on this host.")
    os.mkdir(bolt_dir)

    local record_iters = nil
    for _, candidate_iters in ipairs(_bolt_record_iteration_candidates(iters)) do
        local perf_record_args = {
            "record",
            "-o", perf_data,
            "-e", "cycles:u",
        }
        if use_lbr then
            table.insert(perf_record_args, "-j")
            table.insert(perf_record_args, "any,u")
        end
        table.insert(perf_record_args, "--")
        table.insert(perf_record_args, binary)
        table.insert(perf_record_args, "--case")
        table.insert(perf_record_args, case_name)
        if candidate_iters ~= nil then
            table.insert(perf_record_args, "--iters")
            table.insert(perf_record_args, tostring(candidate_iters))
        end

        local record_program, record_args = task_helpers.pinned_command(perf, perf_record_args)
        task_helpers.write_command_output(perf_record_log, record_program, record_args)
        if _perf_data_has_binary_samples(perf, perf_data, binary) then
            record_iters = candidate_iters
            break
        end
    end

    if record_iters == nil then
        raise("perf recorded no samples for " .. path.filename(binary) .. "; rerun with a larger --iters value for BOLT.")
    end
    local perf2bolt_args = {
        binary,
        "-ignore-build-id",
        "-p", perf_data,
        "-o", fdata,
    }
    if not use_lbr then
        table.insert(perf2bolt_args, 2, "-nl")
    end
    task_helpers.write_command_output(perf2bolt_log, perf2bolt, perf2bolt_args)
    task_helpers.write_command_output(llvm_bolt_log, llvm_bolt, {
        binary,
        "-o", output_binary,
        "--data", fdata,
        "--reorder-blocks=ext-tsp",
        "--reorder-functions=hfsort+",
        "--split-functions",
        "--split-all-cold",
        "--update-debug-sections",
        "--dyno-stats",
    })

    return path.absolute(output_binary), {
        bolt_perf_data = perf_data,
        bolt_perf_record_log = path.absolute(perf_record_log),
        bolt_perf2bolt_log = path.absolute(perf2bolt_log),
        bolt_llvm_bolt_log = path.absolute(llvm_bolt_log),
        bolt_fdata = path.absolute(fdata),
        bolt_binary = path.absolute(output_binary),
        bolt_profile_mode = use_lbr and "lbr" or "sampling",
        bolt_record_iters = record_iters,
    }
end

local function _write_metadata(filename, run_dir, builddir, binary, case_name, iters, samples, warmups,
                               pgo_mode, bolt_mode, artifacts)
    local options = task_helpers.collect_runtime_option_values({
        ["analysis-symbols"] = task_helpers.config_value_string(option.get("analysis-symbols")),
        ["objc-runtime"] = _string_option("objc-runtime", "gnustep-2.3"),
        mode = _string_option("mode", "release"),
        plat = _string_option("plat", "linux"),
        arch = _string_option("arch", "x86_64"),
        pgo = pgo_mode,
        bolt = bolt_mode,
    })

    local metadata = {
        generated_at_utc = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        run_dir = path.absolute(run_dir),
        builddir = path.absolute(builddir),
        binary = path.absolute(binary),
        case = case_name,
        iters = iters,
        samples = samples,
        warmups = warmups,
        artifacts = artifacts,
        options = options,
        host = {
            host = os.host(),
            arch = os.arch(),
            uname = _capture_optional("uname", {"-srvm"}),
            lscpu = _capture_optional("lscpu", {}),
            clang = _capture_optional(task_helpers.clang_program(), {"--version"}),
            xmake = _capture_optional("xmake", {"--version"}),
        },
    }
    io.writefile(filename, json.encode(metadata))
end

function main()
    local host_plat = os.host()
    if host_plat ~= "linux" then
        raise("run-runtime-bench is only supported on Linux hosts.")
    end

    local target_plat = _string_option("plat", "linux")
    local target_arch = _string_option("arch", "x86_64")
    if target_plat ~= "linux" or target_arch ~= "x86_64" then
        raise("run-runtime-bench currently supports only --plat=linux --arch=x86_64.")
    end

    local pgo_mode = _enum_option("pgo", "off", {"off", "gen", "use"})
    local bolt_mode = _enum_option("bolt", "off", {"off", "on"})
    local outroot = _string_option("outdir", path.join("build", "runtime-analysis", "bench"))
    local run_tag = _string_option("tag", os.date("!%Y%m%d-%H%M%SZ"))
    local run_dir = path.join(outroot, run_tag)
    local builddir = _string_option("builddir", path.join(run_dir, "build"))
    local mode_name = _string_option("mode", "release")
    local case_name = _string_option("case", "all")
    local iters = _positive_integer_option("iters", nil)
    local samples = _positive_integer_option("samples", 5)
    local warmups = _nonnegative_integer_option("warmups", 1)
    local configure_log = path.join(run_dir, "configure.log")
    local build_log = path.join(run_dir, "build.log")
    local raw_csv = path.join(run_dir, "raw.csv")
    local summary_json = path.join(run_dir, "summary.json")
    local summary_txt = path.join(run_dir, "summary.txt")
    local metadata_json = path.join(run_dir, "metadata.json")
    local cases_csv = path.join(run_dir, "cases.csv")
    local sample_rows = {"sample,case,iters,total_ns,ns_per"}
    local sample_results = {}
    local artifacts = {
        configure_log = path.absolute(configure_log),
        build_log = path.absolute(build_log),
    }
    local profdata = nil
    local configure_pgo_mode = "off"

    os.mkdir(run_dir)

    if pgo_mode == "use" then
        print(string.format("Training PGO profile for case %s", case_name))
        local pgo_artifacts = nil
        profdata, pgo_artifacts = _run_pgo_training(run_dir, mode_name, case_name, iters)
        for key, value in pairs(pgo_artifacts) do
            artifacts[key] = value
        end
        configure_pgo_mode = "use"
    elseif pgo_mode == "gen" then
        configure_pgo_mode = "gen"
    end

    print(string.format("Configuring runtime benchmark build in %s", builddir))
    task_helpers.write_command_output(configure_log, "xmake", _configure_args(builddir, configure_pgo_mode, profdata))

    print("Building runtime-bench")
    task_helpers.write_command_output(build_log, "xmake", {"b", "runtime-bench"}, {
        envs = {SMALLFW_SKIP_RELEASE_CLANG_TIDY = "1"},
    })

    local runtime_bench = path.absolute(task_helpers.target_binary(builddir, "runtime-bench", mode_name))
    if bolt_mode == "on" then
        print("Applying BOLT post-link optimization")
        local bolt_binary, bolt_artifacts = _bolt_optimize_binary(run_dir, runtime_bench, case_name, iters)
        runtime_bench = bolt_binary
        for key, value in pairs(bolt_artifacts) do
            artifacts[key] = value
        end
    end

    local pgo_env = nil
    if pgo_mode == "gen" then
        local pgo_dir = path.join(run_dir, "pgo")
        os.mkdir(pgo_dir)
        pgo_env = {LLVM_PROFILE_FILE = path.join(path.absolute(pgo_dir), "%m-%p.profraw")}
    end

    local bench_program, bench_list_args = task_helpers.pinned_command(runtime_bench, {"--list"})
    task_helpers.write_command_output(cases_csv, bench_program, bench_list_args)
    artifacts.cases_csv = path.absolute(cases_csv)

    for index = 1, warmups do
        local filename = path.join(run_dir, string.format("warmup-%02d.csv", index))
        print(string.format("Warmup %d/%d", index, warmups))
        local warmup_program, warmup_args = task_helpers.pinned_command(runtime_bench, _bench_args(case_name, iters))
        task_helpers.write_command_output(filename, warmup_program, warmup_args, {envs = pgo_env})
    end

    for index = 1, samples do
        local filename = path.join(run_dir, string.format("sample-%02d.csv", index))
        print(string.format("Sample %d/%d", index, samples))
        local sample_program, sample_args = task_helpers.pinned_command(runtime_bench, _bench_args(case_name, iters))
        task_helpers.write_command_output(filename, sample_program, sample_args, {envs = pgo_env})

        local results = _parse_bench_output(io.readfile(filename))
        if #results == 0 then
            raise("Failed to parse benchmark output from " .. filename)
        end
        table.insert(sample_results, {index = index, results = results})

        for _, result in ipairs(results) do
            _append_csv_row(sample_rows, index, result)
        end
    end

    if pgo_mode == "gen" then
        local pgo_dir = path.join(run_dir, "pgo")
        artifacts.pgo_profdata = path.absolute(_merge_profraws(pgo_dir))
    elseif profdata ~= nil then
        artifacts.pgo_profdata = path.absolute(profdata)
    end

    local summary = _summarize(sample_results)
    local summary_lines = {}
    if #summary == 0 then
        raise("No benchmark results were collected.")
    end

    io.writefile(raw_csv, table.concat(sample_rows, "\n") .. "\n")
    io.writefile(summary_json, json.encode({
        generated_at_utc = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        case = case_name,
        iters = iters,
        cases = summary,
    }))
    for _, item in ipairs(summary) do
        table.insert(summary_lines, string.format(
            "%-30s mean %.3f ns  median %.3f ns  min %.3f ns  max %.3f ns  stdev %.3f ns",
            item.name, item.mean_ns_per, item.median_ns_per, item.min_ns_per, item.max_ns_per, item.stdev_ns_per))
    end
    io.writefile(summary_txt, table.concat(summary_lines, "\n") .. "\n")
    _write_metadata(metadata_json, run_dir, builddir, runtime_bench, case_name, iters, samples, warmups,
        pgo_mode, bolt_mode, artifacts)

    print("Benchmark summary:")
    for _, item in ipairs(summary) do
        print(string.format("  %-30s mean %.3f ns  median %.3f ns  min %.3f ns  max %.3f ns",
            item.name, item.mean_ns_per, item.median_ns_per, item.min_ns_per, item.max_ns_per))
    end
    print(string.format("Artifacts written to %s", path.absolute(run_dir)))
end
