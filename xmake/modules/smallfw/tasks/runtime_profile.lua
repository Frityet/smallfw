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

local function _configure_runtime_args(args)
    for _, key in ipairs({
        "runtime_threadsafe",
        "dispatch_backend",
        "dispatch_stats",
        "runtime_exceptions",
        "runtime_reflection",
        "runtime_validation",
        "runtime_sanitize",
        "runtime_slim_alloc",
    }) do
        local value = task_helpers.config_value_string(option.get(key))
        if value ~= nil and value ~= "" then
            table.insert(args, "--" .. key .. "=" .. value)
        end
    end
end

local function _profile_compile_flags(profiler)
    local common = "-O3 -gdwarf-4 -fno-omit-frame-pointer"
    if profiler == "gprof" then
        return common .. " -pg", "-pg"
    end
    return common, nil
end

local function _configure_args(builddir, profiler)
    local compile_flags, link_flags = _profile_compile_flags(profiler)
    local args = {
        "f",
        "--yes",
        "-m", _string_option("mode", "debug"),
        "-p", _string_option("plat", "linux"),
        "-a", _string_option("arch", "x86_64"),
        "-o", builddir,
        "--analysis_symbols=y",
        "--cflags=" .. compile_flags,
        "--cxflags=" .. compile_flags,
        "--mflags=" .. compile_flags,
        "--mxflags=" .. compile_flags,
    }
    if link_flags ~= nil then
        table.insert(args, "--ldflags=" .. link_flags)
    end
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

local function _write_metadata(filename, run_dir, builddir, binary, profiler, case_name, iters, artifacts)
    local metadata = {
        generated_at_utc = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        run_dir = path.absolute(run_dir),
        builddir = path.absolute(builddir),
        binary = path.absolute(binary),
        profiler = profiler,
        case = case_name,
        iters = iters,
        artifacts = artifacts,
        options = {
            mode = _string_option("mode", "debug"),
            plat = _string_option("plat", "linux"),
            arch = _string_option("arch", "x86_64"),
            dispatch_backend = _string_option("dispatch_backend", nil),
            runtime_threadsafe = _string_option("runtime_threadsafe", nil),
            dispatch_stats = _string_option("dispatch_stats", nil),
            runtime_exceptions = _string_option("runtime_exceptions", nil),
            runtime_reflection = _string_option("runtime_reflection", nil),
            runtime_slim_alloc = _string_option("runtime_slim_alloc", nil),
            runtime_sanitize = _string_option("runtime_sanitize", nil),
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

function main()
    if os.host() ~= "linux" then
        raise("run_runtime_profile is only supported on Linux hosts.")
    end

    local target_plat = _string_option("plat", "linux")
    local target_arch = _string_option("arch", "x86_64")
    if target_plat ~= "linux" or target_arch ~= "x86_64" then
        raise("run_runtime_profile currently supports only --plat=linux --arch=x86_64.")
    end

    local profiler = _select_profiler()
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
    local runtime_bench = path.absolute(task_helpers.target_binary(builddir, "runtime_bench", mode_name))
    local artifacts = {
        configure_log = path.absolute(configure_log),
        build_log = path.absolute(build_log),
        bench_csv = path.absolute(bench_csv),
    }

    os.mkdir(run_dir)

    print(string.format("Configuring instrumented profile build in %s", builddir))
    task_helpers.write_command_output(configure_log, "xmake", _configure_args(builddir, profiler))

    print("Building instrumented runtime_bench")
    task_helpers.write_command_output(build_log, "xmake", {"b", "runtime_bench"})

    print(string.format("Running profiled benchmark case %s via %s", case_name, profiler))
    if profiler == "gprof" then
        local gmon_file = path.join(run_dir, "gmon.out")
        local gprof_txt = path.join(run_dir, "gprof.txt")
        local bench_program, bench_args = task_helpers.pinned_command(runtime_bench, _bench_args(case_name, iters))
        task_helpers.write_command_output(bench_csv, bench_program, bench_args, {
            envs = {GMON_OUT_FILE = gmon_file},
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
        })
        task_helpers.write_command_output(perf_report, "perf", {"report", "--stdio", "-i", perf_data})
        artifacts.perf_data = path.absolute(perf_data)
        artifacts.perf_stat = path.absolute(perf_stat)
        artifacts.profile_report = path.absolute(perf_report)
        artifacts.profile_record_log = path.absolute(perf_record_log)
    end

    local objdump_program = find_program("objdump") or find_program("llvm-objdump")
    if objdump_program ~= nil then
        local objdump_txt = path.join(run_dir, "objc_msgSend.objdump.txt")
        local ok = _write_optional_output(objdump_txt, objdump_program, {"-d", "--disassemble=objc_msgSend", runtime_bench})
        if ok then
            artifacts.objdump = path.absolute(objdump_txt)
        end
    end

    local backend = _string_option("dispatch_backend", "asm")
    local llvm_mca = find_tool("llvm-mca")
    if backend == "asm" and llvm_mca ~= nil and llvm_mca.program ~= nil then
        local asm_input = path.join(run_dir, "objc_msgSend.s")
        local mca_output = path.join(run_dir, "objc_msgSend.llvm-mca.txt")
        local asm_source = path.join(task_helpers.projectdir(), "src", "runtime", "dispatch_x86_64.S")
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
    _write_metadata(metadata_json, run_dir, builddir, runtime_bench, profiler, case_name, iters, artifacts)

    print(string.format("Profile result: %s %.3f ns (%d iterations)",
        bench_result.name, bench_result.ns_per, bench_result.iters))
    print(string.format("Artifacts written to %s", path.absolute(run_dir)))
end
