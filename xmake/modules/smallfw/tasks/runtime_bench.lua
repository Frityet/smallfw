import("core.base.json")
import("core.base.option")
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

local function _configure_runtime_args(args)
    for _, key in ipairs({
        "runtime-threadsafe",
        "dispatch-backend",
        "dispatch-stats",
        "runtime-exceptions",
        "runtime-reflection",
        "runtime-forwarding",
        "runtime-validation",
        "runtime-sanitize",
        "runtime-slim-alloc",
    }) do
        local value = task_helpers.config_value_string(option.get(key))
        if value ~= nil and value ~= "" then
            table.insert(args, "--" .. key .. "=" .. value)
        end
    end
end

local function _configure_args(builddir)
    local args = {
        "f",
        "--yes",
        "-m", _string_option("mode", "release"),
        "-p", _string_option("plat", "linux"),
        "-a", _string_option("arch", "x86_64"),
        "-o", builddir,
        "--analysis-symbols=y",
    }
    _configure_runtime_args(args)
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

local function _write_metadata(filename, run_dir, builddir, binary, case_name, iters, samples, warmups)
    local metadata = {
        generated_at_utc = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        run_dir = path.absolute(run_dir),
        builddir = path.absolute(builddir),
        binary = path.absolute(binary),
        case = case_name,
        iters = iters,
        samples = samples,
        warmups = warmups,
        options = {
            mode = _string_option("mode", "release"),
            plat = _string_option("plat", "linux"),
            arch = _string_option("arch", "x86_64"),
            ["dispatch-backend"] = _string_option("dispatch-backend", nil),
            ["runtime-threadsafe"] = _string_option("runtime-threadsafe", nil),
            ["dispatch-stats"] = _string_option("dispatch-stats", nil),
            ["runtime-exceptions"] = _string_option("runtime-exceptions", nil),
            ["runtime-reflection"] = _string_option("runtime-reflection", nil),
            ["runtime-forwarding"] = _string_option("runtime-forwarding", nil),
            ["runtime-validation"] = _string_option("runtime-validation", nil),
            ["runtime-slim-alloc"] = _string_option("runtime-slim-alloc", nil),
            ["runtime-sanitize"] = _string_option("runtime-sanitize", nil),
        },
        host = {
            host = os.host(),
            arch = os.arch(),
            uname = _capture_optional("uname", {"-srvm"}),
            lscpu = _capture_optional("lscpu", {}),
            clang = _capture_optional("clang", {"--version"}),
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
    local runtime_bench = path.absolute(task_helpers.target_binary(builddir, "runtime-bench", mode_name))
    local sample_rows = {"sample,case,iters,total_ns,ns_per"}
    local sample_results = {}

    os.mkdir(run_dir)

    print(string.format("Configuring runtime benchmark build in %s", builddir))
    task_helpers.write_command_output(configure_log, "xmake", _configure_args(builddir))

    print("Building runtime-bench")
    task_helpers.write_command_output(build_log, "xmake", {"b", "runtime-bench"})

    local bench_program, bench_list_args = task_helpers.pinned_command(runtime_bench, {"--list"})
    task_helpers.write_command_output(cases_csv, bench_program, bench_list_args)

    for index = 1, warmups do
        local filename = path.join(run_dir, string.format("warmup-%02d.csv", index))
        print(string.format("Warmup %d/%d", index, warmups))
        local warmup_program, warmup_args = task_helpers.pinned_command(runtime_bench, _bench_args(case_name, iters))
        task_helpers.write_command_output(filename, warmup_program, warmup_args)
    end

    for index = 1, samples do
        local filename = path.join(run_dir, string.format("sample-%02d.csv", index))
        print(string.format("Sample %d/%d", index, samples))
        local sample_program, sample_args = task_helpers.pinned_command(runtime_bench, _bench_args(case_name, iters))
        task_helpers.write_command_output(filename, sample_program, sample_args)

        local results = _parse_bench_output(io.readfile(filename))
        if #results == 0 then
            raise("Failed to parse benchmark output from " .. filename)
        end
        table.insert(sample_results, {index = index, results = results})

        for _, result in ipairs(results) do
            _append_csv_row(sample_rows, index, result)
        end
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
    _write_metadata(metadata_json, run_dir, builddir, runtime_bench, case_name, iters, samples, warmups)

    print("Benchmark summary:")
    for _, item in ipairs(summary) do
        print(string.format("  %-30s mean %.3f ns  median %.3f ns  min %.3f ns  max %.3f ns",
            item.name, item.mean_ns_per, item.median_ns_per, item.min_ns_per, item.max_ns_per))
    end
    print(string.format("Artifacts written to %s", path.absolute(run_dir)))
end
