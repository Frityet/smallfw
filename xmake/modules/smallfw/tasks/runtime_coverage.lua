import("core.base.json")
import("core.base.option")
import("smallfw.task_helpers")

local function _normalize_path(value)
    return (value or ""):gsub("\\", "/")
end

local function _endswith(value, suffix)
    value = _normalize_path(value)
    suffix = _normalize_path(suffix)
    return #value >= #suffix and value:sub(-#suffix) == suffix
end

local function _relative_to_project(pathstr)
    local root = _normalize_path(task_helpers.projectdir())
    local value = _normalize_path(pathstr)
    if value:sub(1, #root + 1) == root .. "/" then
        return value:sub(#root + 2)
    end
    return value
end

local function _table_size(values)
    local count = 0
    for _ in pairs(values) do
        count = count + 1
    end
    return count
end

local function _lock_helper_name(name)
    if name == nil then
        return false
    end
    return name:find("^sf_runtime_rwlock_") ~= nil or
           name:find("^sf_runtime_mutex_") ~= nil or
           name:find(":sf_runtime_rwlock_", 1, true) ~= nil or
           name:find(":sf_runtime_mutex_", 1, true) ~= nil
end

local function _coverage_matrix()
    return {
        {
            name = "asm_base",
            options = {
                "--dispatch-backend=asm",
                "--runtime-exceptions=y",
                "--runtime-reflection=y",
                "--runtime-forwarding=n",
            },
        },
        {
            name = "asm_forwarding",
            options = {
                "--dispatch-backend=asm",
                "--runtime-exceptions=y",
                "--runtime-reflection=y",
                "--runtime-forwarding=y",
            },
        },
        {
            name = "c_backend",
            options = {
                "--dispatch-backend=c",
                "--runtime-exceptions=y",
                "--runtime-reflection=y",
                "--runtime-forwarding=n",
            },
        },
        {
            name = "asm_min",
            options = {
                "--dispatch-backend=asm",
                "--runtime-exceptions=n",
                "--runtime-reflection=n",
                "--runtime-forwarding=n",
            },
        },
    }
end

local function _coverage_targets()
    local root = task_helpers.projectdir()
    return {
        direct = {
            path.join(root, "src/runtime/arc.c"),
            path.join(root, "src/runtime/dispatch.c"),
            path.join(root, "src/runtime/exceptions.c"),
            path.join(root, "src/runtime/helpers.c"),
            path.join(root, "src/runtime/loader.c"),
        },
        wrappers = {
            {
                path = path.join(root, "src/runtime/allocator.c"),
                suffixes = {"/src/runtime/__cpp_allocator.c.c"},
                ignore_locks = false,
            },
            {
                path = path.join(root, "src/runtime/dispatch_c.c"),
                suffixes = {"/src/runtime/__cpp_dispatch_c.c.c", "/src/runtime/dispatch_c.c"},
                ignore_locks = true,
            },
            {
                path = path.join(root, "src/runtime/testhooks.c"),
                suffixes = {"/src/runtime/__cpp_testhooks.c.c"},
                ignore_locks = true,
            },
            {
                path = path.join(root, "src/smallfw/Object.m"),
                suffixes = {"/src/smallfw/__cpp_Object.m.m"},
                ignore_locks = true,
            },
        },
    }
end

local function _summary_map(summary)
    local result = {}
    for _, datum in ipairs(summary.data or {}) do
        for _, entry in ipairs(datum.files or {}) do
            result[_normalize_path(entry.filename)] = entry.summary
        end
    end
    return result
end

local function _matches_any_suffix(filename, suffixes)
    for _, suffix in ipairs(suffixes or {}) do
        if _endswith(filename, suffix) then
            return true
        end
    end
    return false
end

local function _collect_wrapper_functions(export_data, suffixes, ignore_locks)
    local counts = {}
    for _, datum in ipairs(export_data.data or {}) do
        for _, fn in ipairs(datum.functions or {}) do
            local match = false
            for _, filename in ipairs(fn.filenames or {}) do
                if _matches_any_suffix(filename, suffixes) then
                    match = true
                    break
                end
            end
            if match then
                local name = fn.name
                if not (ignore_locks and _lock_helper_name(name)) then
                    local count = tonumber(fn.count) or 0
                    counts[name] = math.max(counts[name] or 0, count)
                end
            end
        end
    end
    return counts
end

local function _max_wrapper_line_percent(summary, suffixes)
    local percent = 0.0
    for _, datum in ipairs(summary.data or {}) do
        for _, entry in ipairs(datum.files or {}) do
            if _matches_any_suffix(entry.filename, suffixes) then
                percent = math.max(percent, tonumber(entry.summary.lines.percent) or 0.0)
            end
        end
    end
    return percent
end

local function _export_coverage(llvm_cov, binaries, profile, summary_only)
    local args = {"export", binaries[1]}
    for index = 2, #binaries do
        table.insert(args, "--object")
        table.insert(args, binaries[index])
    end
    table.insert(args, "-instr-profile=" .. profile)
    table.insert(args, "--ignore-filename-regex=.*/dispatch_x86_64\\.S$")
    if summary_only then
        table.insert(args, "--summary-only")
    end
    local stdout = os.iorunv(llvm_cov.program, args)
    return json.decode(stdout)
end

local function _check_coverage(summary, export_data)
    local targets = _coverage_targets()
    local summaries = _summary_map(summary)
    local failures = {}

    print("Direct source line coverage:")
    for _, filename in ipairs(targets.direct) do
        local summary_entry = summaries[_normalize_path(filename)]
        if summary_entry == nil then
            table.insert(failures, "missing direct coverage summary for " .. _relative_to_project(filename))
        else
            local percent = tonumber(summary_entry.lines.percent) or 0.0
            print(string.format("  %6.2f%% %s", percent, _relative_to_project(filename)))
            if percent < 100.0 then
                table.insert(failures,
                    string.format("%s line coverage %.2f%% != 100%%", _relative_to_project(filename), percent))
            end
        end
    end

    print("Wrapper-mapped runtime function coverage:")
    for _, wrapper in ipairs(targets.wrappers) do
        local counts = _collect_wrapper_functions(export_data, wrapper.suffixes, wrapper.ignore_locks)
        local total = _table_size(counts)
        if total == 0 then
            table.insert(failures, "missing wrapper function coverage for " .. _relative_to_project(wrapper.path))
        else
            local uncovered = {}
            for name, count in pairs(counts) do
                if count == 0 then
                    table.insert(uncovered, name)
                end
            end
            table.sort(uncovered)
            local covered = total - #uncovered
            local raw_percent = _max_wrapper_line_percent(summary, wrapper.suffixes)
            print(string.format("  %2d/%2d functions executed %s (raw wrapper lines %.2f%%)",
                covered, total, _relative_to_project(wrapper.path), raw_percent))
            if #uncovered > 0 then
                table.insert(failures,
                    string.format("%s uncovered wrapper functions: %s",
                        _relative_to_project(wrapper.path), table.concat(uncovered, ", ")))
            end
        end
    end

    if #failures > 0 then
        raise("Coverage check failed:\n  - " .. table.concat(failures, "\n  - "))
    end
    print("Coverage check passed.")
end

function main()
    if os.host() ~= "linux" then
        raise("run-runtime-coverage is only supported on Linux hosts.")
    end

    local llvm_profdata = task_helpers.llvm_profdata_program()
    local llvm_cov = task_helpers.find_required_tool("llvm-cov", "llvm-cov not found")
    local outdir = option.get("outdir") or path.join("build", "cov-matrix")
    local cov_flags = "-fprofile-instr-generate -fcoverage-mapping"
    local profile_pattern = path.join("%s", "profiles", "%%m-%%p.profraw")
    local matrix = _coverage_matrix()
    local binaries = {}
    local profraws = {}

    os.rm(outdir)
    os.mkdir(outdir)

    for _, entry in ipairs(matrix) do
        local builddir = path.join(outdir, entry.name)
        local profdir = path.join(builddir, "profiles")
        local runtime_tests = task_helpers.target_binary(builddir, "runtime-tests", "debug")
        local configure_log = builddir .. ".configure.log"
        local build_log = builddir .. ".build.log"
        local run_log = builddir .. ".run.log"
        local configure_args = {
            "f",
            "-c",
            "-m", "debug",
            "-o", builddir,
            "--cflags=" .. cov_flags,
            "--cxflags=" .. cov_flags,
            "--mflags=" .. cov_flags,
            "--mxflags=" .. cov_flags,
            "--ldflags=-fprofile-instr-generate",
        }
        task_helpers.append_runtime_toolchain_args(configure_args)

        for _, value in ipairs(entry.options) do
            table.insert(configure_args, value)
        end

        os.mkdir(profdir)

        print(string.format("Configuring coverage build %s", entry.name))
        task_helpers.write_command_output(configure_log, "xmake", configure_args)

        print(string.format("Building coverage target %s", entry.name))
        task_helpers.write_command_output(build_log, "xmake", {"b", "runtime-tests"})

        print(string.format("Running coverage target %s", entry.name))
        task_helpers.write_command_output(run_log, runtime_tests, {"--all"}, {
            envs = {LLVM_PROFILE_FILE = string.format(profile_pattern, builddir)},
        })

        table.insert(binaries, runtime_tests)
        for _, profraw in ipairs(os.files(path.join(profdir, "*.profraw"))) do
            table.insert(profraws, profraw)
        end
    end

    if #profraws == 0 then
        raise("No .profraw files were generated under " .. outdir)
    end

    table.sort(profraws)

    local merged_profdata = path.join(outdir, "merged.profdata")
    local merge_args = {"merge", "-sparse"}
    for _, profraw in ipairs(profraws) do
        table.insert(merge_args, profraw)
    end
    table.insert(merge_args, "-o")
    table.insert(merge_args, merged_profdata)
    os.execv(llvm_profdata, merge_args)

    local summary = _export_coverage(llvm_cov, binaries, merged_profdata, true)
    local export_data = _export_coverage(llvm_cov, binaries, merged_profdata, false)
    io.writefile(path.join(outdir, "summary.json"), json.encode(summary))
    io.writefile(path.join(outdir, "export.json"), json.encode(export_data))
    _check_coverage(summary, export_data)
end
