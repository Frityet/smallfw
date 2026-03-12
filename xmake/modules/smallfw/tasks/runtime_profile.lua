import("core.base.json")
import("core.base.option")
import("lib.detect.find_program")
import("lib.detect.find_tool")
import("smallfw.task_helpers")

local function _string_option(name, default_value)
    local value = option.get(name)
    if value == nil or value == "" then
        return default_value
    end
    return value
end

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

local function _profile_compile_flags(profiler)
    local compile_flags = {"-O3", "-gdwarf-4", "-fno-omit-frame-pointer"}
    local link_flags = {}
    if profiler == "gprof" then
        table.insert(compile_flags, "-pg")
        table.insert(link_flags, "-pg")
    end
    return compile_flags, link_flags
end

local function _configure_args(builddir, profiler, pgo_mode, profdata)
    local extra_args = {}
    if option.get("analysis-symbols") == nil or option.get("analysis-symbols") == "" then
        table.insert(extra_args, "--analysis-symbols=y")
    end
    local args = task_helpers.collect_configure_args(extra_args, {
        mode = _string_option("mode", "debug"),
        plat = _string_option("plat", "linux"),
        arch = _string_option("arch", "x86_64"),
        builddir = builddir,
    })
    local compile_flags, link_flags = _profile_compile_flags(profiler)

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

local function _select_profiler()
    local requested = _string_option("profiler", "auto")
    if requested == "gprof" then
        task_helpers.find_required_program("gprof", "gprof not found")
        return "gprof"
    end
    if requested == "perf" then
        local perf = task_helpers.find_required_program("perf", "perf not found")
        assert(_perf_usable(perf), "perf is installed, but perf events are not permitted on this host.")
        return "perf"
    end

    local perf = find_program("perf")
    if perf ~= nil and _perf_usable(perf) then
        return "perf"
    end

    if find_program("gprof") ~= nil then
        return "gprof"
    end
    raise("No supported profiler is available. Install gprof or perf.")
end

local function _parse_bench_output(text)
    for line in (text or ""):gmatch("[^\r\n]+") do
        local name, iters, total_ns, ns_per = line:match("^([^,]+),(%d+),(%d+),([%d%.]+)$")
        if name ~= nil then
            return {
                name = name,
                iters = assert(tonumber(iters)),
                total_ns = assert(tonumber(total_ns)),
                ns_per = assert(tonumber(ns_per)),
            }
        end
    end
    return nil
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

local function _run_pgo_training(run_dir, profiler, mode_name, case_name, iters)
    local pgo_dir = path.join(run_dir, "pgo")
    local builddir = path.join(pgo_dir, "build")
    local configure_log = path.join(pgo_dir, "configure.log")
    local build_log = path.join(pgo_dir, "build.log")
    local train_log = path.join(pgo_dir, "train.csv")
    local prof_pattern = path.join(path.absolute(pgo_dir), "%m-%p.profraw")
    local runtime_bench = path.absolute(task_helpers.target_binary(builddir, "runtime-bench", mode_name))

    os.mkdir(pgo_dir)

    task_helpers.write_command_output(configure_log, "xmake", _configure_args(builddir, profiler, "gen"))
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

        local perf_record_program, perf_record_command_args = task_helpers.pinned_command(perf, perf_record_args)
        task_helpers.write_command_output(perf_record_log, perf_record_program, perf_record_command_args)
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

    return {
        bolt_perf_data = path.absolute(perf_data),
        bolt_perf_record_log = path.absolute(perf_record_log),
        bolt_perf2bolt_log = path.absolute(perf2bolt_log),
        bolt_llvm_bolt_log = path.absolute(llvm_bolt_log),
        bolt_fdata = path.absolute(fdata),
        bolt_binary = path.absolute(output_binary),
        bolt_profile_mode = use_lbr and "lbr" or "sampling",
        bolt_record_iters = record_iters,
    }
end

local function _extract_asm_symbol(symbol_name, sourcefile, outfile)
    local source = io.readfile(sourcefile)
    if source == nil then
        return false
    end

    local lines = {}
    local capture = false
    for line in source:gmatch("([^\n]*)\n?") do
        if line == symbol_name .. ":" then
            capture = true
        end
        if capture then
            table.insert(lines, line)
        end
        if capture and line:find("^%.size%s+" .. symbol_name) then
            break
        end
    end

    if #lines == 0 then
        return false
    end

    table.insert(lines, 1, ".text")
    io.writefile(outfile, table.concat(lines, "\n") .. "\n")
    return true
end

local function _write_optional_output(filename, program, args, opt)
    local ok, errs = try {
        function ()
            task_helpers.write_command_output(filename, program, args, opt)
            return true
        end,
        catch {
            function (errors)
                return false, errors
            end
        }
    }
    return ok, errs
end

local function _write_metadata(filename, run_dir, builddir, binary, profiler, case_name, iters,
                               pgo_mode, bolt_mode, artifacts)
    local options = task_helpers.collect_runtime_option_values({
        mode = _string_option("mode", "debug"),
        plat = _string_option("plat", "linux"),
        arch = _string_option("arch", "x86_64"),
        profiler = profiler,
        pgo = pgo_mode,
        bolt = bolt_mode,
    })

    local metadata = {
        generated_at_utc = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        run_dir = path.absolute(run_dir),
        builddir = path.absolute(builddir),
        binary = path.absolute(binary),
        profiler = profiler,
        case = case_name,
        iters = iters,
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
    if os.host() ~= "linux" then
        raise("run-runtime-profile is only supported on Linux hosts.")
    end

    local target_plat = _string_option("plat", "linux")
    local target_arch = _string_option("arch", "x86_64")
    if target_plat ~= "linux" or target_arch ~= "x86_64" then
        raise("run-runtime-profile currently supports only --plat=linux --arch=x86_64.")
    end

    local profiler = _select_profiler()
    local pgo_mode = _enum_option("pgo", "off", {"off", "gen", "use"})
    local bolt_mode = _enum_option("bolt", "off", {"off", "on"})
    assert(bolt_mode == "off" or profiler == "perf", "--bolt=on requires profiler=perf")

    local outroot = _string_option("outdir", path.join("build", "runtime-analysis", "profile"))
    local run_tag = _string_option("tag", os.date("!%Y%m%d-%H%M%SZ"))
    local run_dir = path.join(outroot, run_tag)
    local builddir = _string_option("builddir", path.join(run_dir, "build"))
    local mode_name = _string_option("mode", "debug")
    local case_name = _string_option("case", "dispatch_monomorphic_hot")
    local iters = _positive_integer_option("iters", nil)
    local configure_log = path.join(run_dir, "configure.log")
    local build_log = path.join(run_dir, "build.log")
    local bench_csv = path.join(run_dir, "bench.csv")
    local summary_json = path.join(run_dir, "summary.json")
    local summary_txt = path.join(run_dir, "summary.txt")
    local metadata_json = path.join(run_dir, "metadata.json")
    local artifacts = {
        configure_log = path.absolute(configure_log),
        build_log = path.absolute(build_log),
        bench_csv = path.absolute(bench_csv),
    }
    local configure_pgo_mode = "off"
    local profdata = nil

    os.mkdir(run_dir)

    if pgo_mode == "use" then
        print(string.format("Training PGO profile for case %s", case_name))
        local pgo_artifacts = nil
        profdata, pgo_artifacts = _run_pgo_training(run_dir, profiler, mode_name, case_name, iters)
        for key, value in pairs(pgo_artifacts) do
            artifacts[key] = value
        end
        configure_pgo_mode = "use"
    elseif pgo_mode == "gen" then
        configure_pgo_mode = "gen"
    end

    print(string.format("Configuring instrumented profile build in %s", builddir))
    task_helpers.write_command_output(configure_log, "xmake", _configure_args(builddir, profiler, configure_pgo_mode, profdata))

    print("Building instrumented runtime-bench")
    task_helpers.write_command_output(build_log, "xmake", {"b", "runtime-bench"}, {
        envs = {SMALLFW_SKIP_RELEASE_CLANG_TIDY = "1"},
    })

    local runtime_bench = path.absolute(task_helpers.target_binary(builddir, "runtime-bench", mode_name))
    local pgo_env = nil
    if pgo_mode == "gen" then
        local pgo_dir = path.join(run_dir, "pgo")
        os.mkdir(pgo_dir)
        pgo_env = {LLVM_PROFILE_FILE = path.join(path.absolute(pgo_dir), "%m-%p.profraw")}
    end

    print(string.format("Running profiled benchmark case %s via %s", case_name, profiler))
    if profiler == "gprof" then
        local gmon_file = path.join(run_dir, "gmon.out")
        local gprof_txt = path.join(run_dir, "gprof.txt")
        local bench_program, bench_args = task_helpers.pinned_command(runtime_bench, _bench_args(case_name, iters))
        local envs = {GMON_OUT_FILE = gmon_file}
        if pgo_env ~= nil then
            envs.LLVM_PROFILE_FILE = pgo_env.LLVM_PROFILE_FILE
        end
        task_helpers.write_command_output(bench_csv, bench_program, bench_args, {
            envs = envs,
            curdir = run_dir,
        })
        task_helpers.write_command_output(gprof_txt, "gprof", {runtime_bench, gmon_file})
        artifacts.gmon_out = path.absolute(gmon_file)
        artifacts.profile_report = path.absolute(gprof_txt)
    else
        local perf_data = path.absolute(path.join(run_dir, "perf.data"))
        local perf_record_log = path.join(run_dir, "perf.record.log")
        local perf_report = path.join(run_dir, "perf.report.txt")
        local perf_stat = path.join(run_dir, "perf.stat.txt")
        local perf_bench_program, perf_bench_args = task_helpers.pinned_command(runtime_bench, _bench_args(case_name, iters))

        task_helpers.write_command_output(bench_csv, perf_bench_program, perf_bench_args, {
            curdir = run_dir,
            envs = pgo_env,
        })
        local perf_stat_program, perf_stat_args = task_helpers.pinned_command("perf", {
            "stat",
            "-d",
            runtime_bench,
            "--case", case_name,
            table.unpack(iters ~= nil and {"--iters", tostring(iters)} or {}),
        })
        task_helpers.write_command_output(perf_stat, perf_stat_program, perf_stat_args, {
            curdir = run_dir,
            envs = pgo_env,
        })
        local perf_record_program, perf_record_args = task_helpers.pinned_command("perf", {
            "record",
            "-o", perf_data,
            "-g",
            runtime_bench,
            "--case", case_name,
            table.unpack(iters ~= nil and {"--iters", tostring(iters)} or {}),
        })
        task_helpers.write_command_output(perf_record_log, perf_record_program, perf_record_args, {
            curdir = run_dir,
            envs = pgo_env,
        })
        task_helpers.write_command_output(perf_report, "perf", {"report", "--stdio", "-i", perf_data})
        artifacts.perf_data = path.absolute(perf_data)
        artifacts.perf_stat = path.absolute(perf_stat)
        artifacts.profile_report = path.absolute(perf_report)
        artifacts.profile_record_log = path.absolute(perf_record_log)

        if bolt_mode == "on" then
            local bolt_artifacts = _bolt_optimize_binary(run_dir, runtime_bench, case_name, iters)
            for key, value in pairs(bolt_artifacts) do
                artifacts[key] = value
            end
        end
    end

    if pgo_mode == "gen" then
        artifacts.pgo_profdata = path.absolute(_merge_profraws(path.join(run_dir, "pgo")))
    elseif profdata ~= nil then
        artifacts.pgo_profdata = path.absolute(profdata)
    end

    local objdump_program = find_program("objdump") or find_program("llvm-objdump")
    if objdump_program ~= nil then
        local objdump_txt = path.join(run_dir, "objc_msgSend.objdump.txt")
        local ok = _write_optional_output(objdump_txt, objdump_program, {"-d", "--disassemble=objc_msgSend", runtime_bench})
        if ok then
            artifacts.objdump = path.absolute(objdump_txt)
        end
    end

    local backend = _string_option("dispatch-backend", "asm")
    local llvm_mca = find_tool("llvm-mca")
    if backend == "asm" and llvm_mca ~= nil and llvm_mca.program ~= nil then
        local asm_input = path.join(run_dir, "objc_msgSend.s")
        local mca_output = path.join(run_dir, "objc_msgSend.llvm-mca.txt")
        local asm_source = path.join(task_helpers.projectdir(), "src", "runtime", "dispatch_x86_64.asm")
        if _extract_asm_symbol("objc_msgSend", asm_source, asm_input) then
            local ok = _write_optional_output(mca_output, llvm_mca.program, {
                "-mtriple=x86_64-unknown-linux-gnu",
                asm_input,
            })
            if ok then
                artifacts.asm_input = path.absolute(asm_input)
                artifacts.llvm_mca = path.absolute(mca_output)
            end
        end
    end

    local bench_result = _parse_bench_output(io.readfile(bench_csv))
    if bench_result == nil then
        raise("Failed to parse benchmark output from " .. bench_csv)
    end

    io.writefile(summary_json, json.encode({
        generated_at_utc = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        profiler = profiler,
        benchmark = bench_result,
    }))
    io.writefile(summary_txt, string.format(
        "%s %.3f ns (%d iterations) via %s\n",
        bench_result.name, bench_result.ns_per, bench_result.iters, profiler))
    _write_metadata(metadata_json, run_dir, builddir, runtime_bench, profiler, case_name, iters,
        pgo_mode, bolt_mode, artifacts)

    print(string.format("Profile result: %s %.3f ns (%d iterations)",
        bench_result.name, bench_result.ns_per, bench_result.iters))
    print(string.format("Artifacts written to %s", path.absolute(run_dir)))
end
