import("core.base.json")
import("core.base.option")
import("core.project.project")
import("lib.detect.find_program")
import("smallfw.task_helpers")

local DEFAULT_TARGETS = {
    "runtime-tests",
    "runtime-bench",
    "particle-sim",
}

local CHECKER_CACHE = nil

local function _append_all(dst, src)
    for _, item in ipairs(src or {}) do
        table.insert(dst, item)
    end
end

local function _split_list(value)
    local items = {}
    local seen = {}
    for item in tostring(value or ""):gmatch("[^,:%s]+") do
        if not seen[item] then
            seen[item] = true
            table.insert(items, item)
        end
    end
    return items
end

local function _analyze_build_program()
    local llvm_root = task_helpers.llvm_rootdir()
    local candidates = {
        llvm_root and path.join(llvm_root, "bin", "analyze-build" .. task_helpers.exe_suffix()) or nil,
        "analyze-build",
    }

    for _, candidate in ipairs(candidates) do
        if candidate ~= nil and candidate ~= "" then
            local program = nil
            if path.is_absolute(candidate) then
                if os.isfile(candidate) then
                    program = candidate
                end
            else
                program = find_program(candidate)
            end
            if program ~= nil then
                return program
            end
        end
    end

    raise("analyze-build not found. Install clang-tools / scan-build-py.")
end

local function _clang_extdef_mapping_program()
    local llvm_root = task_helpers.llvm_rootdir()
    local candidates = {
        llvm_root and path.join(llvm_root, "bin", "clang-extdef-mapping" .. task_helpers.exe_suffix()) or nil,
        "clang-extdef-mapping",
    }

    for _, candidate in ipairs(candidates) do
        if candidate ~= nil and candidate ~= "" then
            local program = nil
            if path.is_absolute(candidate) then
                if os.isfile(candidate) then
                    program = candidate
                end
            else
                program = find_program(candidate)
            end
            if program ~= nil then
                return program
            end
        end
    end
    return nil
end

local function _report_format_args(format)
    if format == "html" then
        return {}
    elseif format == "plist" then
        return {"--plist"}
    elseif format == "plist-html" then
        return {"--plist-html"}
    elseif format == "sarif" then
        return {"--sarif"}
    end
    raise("unsupported analyzer report format: " .. tostring(format))
end

local function _targets()
    local targets = _split_list(option.get("targets"))
    if #targets == 0 then
        local defaults = {}
        _append_all(defaults, DEFAULT_TARGETS)
        return defaults
    end
    return targets
end

local function _option_enabled(name, default_value)
    local value = task_helpers.config_value_string(option.get(name))
    if value == nil or value == "" then
        return default_value ~= false
    end
    return value ~= "n"
end

local function _strict_enabled()
    return _option_enabled("strict", false)
end

local function _ctu_enabled()
    return _option_enabled("ctu", false) and _clang_extdef_mapping_program() ~= nil
end

local function _maxloop_value()
    local raw = option.get("maxloop") or "16"
    local value = tonumber(raw)
    if value == nil or value < 1 then
        raise("invalid analyzer maxloop value: " .. tostring(raw))
    end
    return tostring(math.floor(value))
end

local function _xmake_argv(args)
    local argv = {}
    if option.get("verbose") then
        table.insert(argv, "-v")
    end
    if option.get("diagnosis") then
        table.insert(argv, "-D")
    end
    _append_all(argv, args)
    return argv
end

local function _available_checker_names(analyzer)
    if CHECKER_CACHE ~= nil then
        return CHECKER_CACHE
    end

    local ok, output, errors = task_helpers.try_command_output(analyzer, {"--help-checkers-verbose"})
    if not ok then
        raise("failed to enumerate clang analyzer checkers: %s", tostring(errors))
    end

    local names = {}
    local seen = {}
    for line in (output or ""):gmatch("[^\r\n]+") do
        local checker = line:match("^%s*[+]?%s*([%w%._%-]+)%s*$")
        if checker == nil then
            checker = line:match("^%s*[+]?%s*([%w%._%-]+)%s%s+")
        end
        if checker ~= nil and checker:find("%.") ~= nil and not seen[checker] then
            seen[checker] = true
            table.insert(names, checker)
        end
    end
    assert(#names > 0, "no clang analyzer checkers were discovered")
    CHECKER_CACHE = names
    return CHECKER_CACHE
end

local function _configure_project(builddir)
    task_helpers.run_xmake(task_helpers.collect_configure_args({
        "--ccache=n",
    }, {
        builddir = builddir,
        mode = "release",
    }))
end

local function _generate_compile_commands(outdir)
    local cdbdir = path.join(outdir, "cdb")
    os.rm(cdbdir)
    os.mkdir(cdbdir)
    os.runv("xmake", _xmake_argv({
        "project",
        "-k", "compile_commands",
        cdbdir,
    }))
    return path.join(cdbdir, "compile_commands.json")
end

local function _dependency_targets(target_names)
    local closure = {}
    local targets = project.targets()
    for _, target_name in ipairs(target_names) do
        local target = targets[target_name]
        assert(target ~= nil, "unknown analysis target: " .. tostring(target_name))
        closure[target_name] = true
        for _, dep in ipairs(target:orderdeps()) do
            closure[dep:name()] = true
        end
    end
    return closure
end

local function _entry_output(entry)
    for index, value in ipairs(entry.arguments or {}) do
        if value == "-o" then
            return entry.arguments[index + 1]
        end
    end
    return nil
end

local function _entry_target(entry)
    local output = _entry_output(entry)
    if output == nil then
        return nil
    end
    local normalized = output:gsub("\\", "/")
    return normalized:match("/%.objs/([^/]+)/") or normalized:match("^%.objs/([^/]+)/")
end

local function _entry_is_analyzable(entry)
    local file = tostring(entry.file or ""):lower()
    if file:match("%.s$") or file:match("%.asm$") then
        return false
    end
    for index, value in ipairs(entry.arguments or {}) do
        if value == "-x" and entry.arguments[index + 1] == "assembler-with-cpp" then
            return false
        end
    end
    return true
end

local function _filtered_cdb_entries(cdbfile, target_names)
    local closure = _dependency_targets(target_names)
    local entries = json.loadfile(cdbfile)
    local filtered = {}

    for _, entry in ipairs(entries or {}) do
        local entry_target = _entry_target(entry)
        if entry_target ~= nil and closure[entry_target] and _entry_is_analyzable(entry) then
            table.insert(filtered, {
                directory = entry.directory,
                file = entry.file,
                command = os.args(entry.arguments or {}),
            })
        end
    end

    if #filtered == 0 then
        raise("no compile commands matched targets: %s", table.concat(target_names, ", "))
    end
    return filtered
end

local function _write_filtered_cdb(outdir, name, entries)
    local cdbfile = path.join(outdir, name .. ".compile_commands.json")
    json.savefile(cdbfile, json.mark_as_array(entries))
    return cdbfile
end

local function _analysis_args(analyzer, opt)
    opt = opt or {}
    local args = {
        "--cdb", opt.cdbfile,
        "--output", opt.outdir,
        "--status-bugs",
        "--keep-empty",
        "--html-title", "smallfw clang static analyzer",
        "--use-analyzer", task_helpers.clang_program(),
        "--analyzer-config", "stable-report-filename=true",
        "--maxloop", _maxloop_value(),
        "--force-analyze-debug-code",
    }

    if _option_enabled("analyze-headers", true) and opt.analyze_headers ~= false then
        table.insert(args, "--analyze-headers")
    end
    if _strict_enabled() then
        for _, checker in ipairs(_available_checker_names(analyzer)) do
            table.insert(args, "--enable-checker")
            table.insert(args, checker)
        end
        if _ctu_enabled() and opt.ctu ~= false then
            table.insert(args, "--ctu")
        end
    end
    if option.get("verbose") then
        table.insert(args, "--verbose")
    end
    if option.get("diagnosis") then
        table.insert(args, "--verbose")
    end
    _append_all(args, _report_format_args(opt.report_format or option.get("report-format") or "html"))
    return args
end

local function _run_analyzer(program, args)
    return try {
        function ()
            os.runv(program, args)
            return true, nil
        end,
        catch {
            function (errors)
                return false, errors
            end
        }
    }
end

local function _analysis_report_files(outdir)
    local files = {}
    _append_all(files, os.files(path.join(outdir, "scan-build-*", "report-*.plist")))
    _append_all(files, os.files(path.join(outdir, "scan-build-*", "report-*.html")))
    _append_all(files, os.files(path.join(outdir, "scan-build-*", "result.sarif")))
    return files
end

function main()
    local analyzer = _analyze_build_program()
    local outdir = option.get("outdir") or path.join("build", "scan-build")
    local builddir = option.get("builddir") or path.join(outdir, "build")
    local targets = _targets()

    os.rm(outdir)
    os.mkdir(outdir)

    _configure_project(builddir)
    local compile_commands_file = _generate_compile_commands(outdir)

    local filtered_entries = _filtered_cdb_entries(compile_commands_file, targets)
    local filtered_cdb = _write_filtered_cdb(outdir, "targets", filtered_entries)
    local enabled_checker_count = _strict_enabled() and #_available_checker_names(analyzer) or 0
    local args = _analysis_args(analyzer, {
        cdbfile = filtered_cdb,
        outdir = outdir,
    })

    print("Running analyzer for targets: %s", table.concat(targets, ", "))
    if _strict_enabled() then
        print("Enabled analyzer checkers: %d%s", enabled_checker_count, _ctu_enabled() and " (+ CTU)" or "")
    end
    print("Analyzer reports: %s", path.absolute(outdir))
    local ok, errors = _run_analyzer(analyzer, args)
    if not ok then
        local reports = _analysis_report_files(outdir)
        if #reports > 0 then
            raise("clang static analyzer reported %d finding(s); see %s", #reports, path.absolute(outdir))
        end
        raise(errors)
    end
end
