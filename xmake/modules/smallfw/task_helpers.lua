import("core.base.option")
import("core.project.config")
import("lib.detect.find_program")
import("lib.detect.find_tool")

local runtime_config_keys = {
    "analysis-symbols",
    "objc-runtime",
    "dispatch-backend",
    "runtime-exceptions",
    "runtime-reflection",
    "runtime-forwarding",
    "runtime-generic-metadata",
    "runtime-validation",
    "runtime-tagged-pointers",
    "runtime-sanitize",
    "runtime-native-tuning",
    "runtime-thinlto",
    "runtime-full-lto",
    "runtime-compact-headers",
    "runtime-inline-value-storage",
    "runtime-inline-group-state",
}

local detected_tools = {}

local function _append_all(dst, src)
    for _, value in ipairs(src or {}) do
        table.insert(dst, value)
    end
end

local function _append_config_arg(args, flag, value)
    if value ~= nil and value ~= "" then
        table.insert(args, flag)
        table.insert(args, value)
    end
end

function projectdir()
    return os.projectdir()
end

function config_value_string(value)
    if value == nil or value == "" then
        return nil
    end
    if type(value) == "boolean" then
        return value and "y" or "n"
    end
    return tostring(value)
end

function exe_suffix()
    return os.host() == "windows" and ".exe" or ""
end

function load_project_config()
    config.load()
end

function current_builddir()
    load_project_config()
    return config.get("buildir") or config.get("builddir") or "build"
end

local function _cached_lookup(cache_key, finder)
    local cached = detected_tools[cache_key]
    if cached ~= nil then
        return cached ~= false and cached or nil
    end

    local value = finder()
    detected_tools[cache_key] = value or false
    return value
end

local function _copy_table(src)
    local dst = {}
    for key, value in pairs(src or {}) do
        dst[key] = value
    end
    return dst
end

local function _configured_program(...)
    load_project_config()
    for _, key in ipairs({...}) do
        local value = config.get(key)
        if value ~= nil and value ~= "" then
            return value
        end
    end
    return nil
end

local function _find_first_tool(candidates)
    for _, candidate in ipairs(candidates or {}) do
        local opt = _copy_table(candidate.opt)
        local tool = nil
        if candidate.program ~= nil and candidate.program ~= "" then
            opt.program = candidate.program
        end
        if candidate.program == nil or candidate.program ~= "" then
            tool = find_tool(candidate.toolname, opt)
        end
        if tool ~= nil and tool.program ~= nil then
            return tool
        end
    end
    return nil
end

local function _first_existing_program(candidates)
    for _, candidate in ipairs(candidates or {}) do
        if candidate ~= nil and candidate ~= "" then
            if path.is_absolute(candidate) then
                if os.isfile(candidate) then
                    return candidate
                end
            else
                local program = find_program(candidate)
                if program ~= nil then
                    return program
                end
            end
        end
    end
    return nil
end

local function _llvm_program_path(name)
    local root = llvm_rootdir()
    if root == nil then
        return nil
    end
    return path.join(root, "bin", name .. exe_suffix())
end

local function _llvm_versioned_program(name)
    local major = llvm_major_version()
    if major == nil then
        return nil
    end
    return name .. "-" .. tostring(major)
end

function llvm_resource_dir()
    local ok, output = try_command_output(clang_program(), {"--print-resource-dir"})
    if not ok then
        return nil
    end
    local resource_dir = trim(output)
    if resource_dir == "" then
        return nil
    end
    return resource_dir
end

function llvm_major_version()
    local resource_dir = llvm_resource_dir()
    local version = resource_dir and resource_dir:match("/clang/(%d+)$")
    if version ~= nil then
        return tonumber(version)
    end

    local ok, clang_version = try_command_output(clang_program(), {"--version"})
    if not ok then
        return nil
    end
    return tonumber((clang_version or ""):match("clang version (%d+)"))
end

function llvm_rootdir()
    local resource_dir = llvm_resource_dir()
    if resource_dir ~= nil then
        return path.directory(path.directory(path.directory(resource_dir)))
    end

    local clang = path.absolute(clang_program())
    return path.directory(path.directory(clang))
end

function find_required_llvm_program(tool_name, message, aliases)
    local tool = _cached_lookup("llvm:" .. tool_name, function ()
        local candidates = {
            {toolname = tool_name, program = _llvm_program_path(tool_name), opt = {version = true}},
            {toolname = tool_name, program = _llvm_versioned_program(tool_name), opt = {version = true}},
        }

        for _, alias in ipairs(aliases or {}) do
            table.insert(candidates, {toolname = tool_name, program = _llvm_program_path(alias), opt = {version = true}})
            table.insert(candidates, {toolname = tool_name, program = _llvm_versioned_program(alias), opt = {version = true}})
            table.insert(candidates, {toolname = tool_name, program = alias, opt = {version = true}})
        end

        table.insert(candidates, {toolname = tool_name, opt = {version = true}})
        return _find_first_tool(candidates)
    end)
    assert(tool and tool.program, message or (tool_name .. " not found"))
    return tool.program
end

function clang_program()
    local tool = _cached_lookup("clang", function ()
        return _find_first_tool({
            {toolname = "clang", program = _configured_program("cc", "mm"), opt = {version = true}},
            {toolname = "clang", opt = {version = true}},
        })
    end)
    assert(tool and tool.program, "clang not found")
    return tool.program
end

function clangxx_program()
    local tool = _cached_lookup("clangxx", function ()
        local clang_real = path.absolute(clang_program())
        return _find_first_tool({
            {toolname = "clang", program = _configured_program("cxx", "mxx"), opt = {version = true}},
            {toolname = "clang", program = path.join(path.directory(clang_real), "clang++" .. exe_suffix()), opt = {version = true}},
            {toolname = "clang", program = "clang++", opt = {version = true}},
        })
    end)
    assert(tool and tool.program, "clang++ not found")
    return tool.program
end

function lld_program()
    local tool = _cached_lookup("ld.lld", function ()
        return _find_first_tool({
            {toolname = "ld.lld", program = _llvm_program_path("ld.lld"), opt = {version = true}},
            {toolname = "ld.lld", program = _llvm_versioned_program("ld.lld"), opt = {version = true}},
            {toolname = "ld.lld", opt = {version = true}},
        })
    end)
    assert(tool and tool.program, "ld.lld not found")
    return tool.program
end

function llvm_profdata_program()
    local tool = _cached_lookup("llvm-profdata", function ()
        return _find_first_tool({
            {toolname = "llvm-profdata", program = _llvm_program_path("llvm-profdata"), opt = {version = true}},
            {toolname = "llvm-profdata", program = _llvm_versioned_program("llvm-profdata"), opt = {version = true}},
            {toolname = "llvm-profdata", opt = {version = true}},
        })
    end)
    assert(tool and tool.program, "llvm-profdata not found")
    return tool.program
end

function llvm_bolt_program()
    return find_required_llvm_program("llvm-bolt", "llvm-bolt not found", {"bolt"})
end

function perf2bolt_program()
    return find_required_llvm_program("perf2bolt", "perf2bolt not found")
end

function profile_runtime_library()
    local resource_dir = llvm_resource_dir()
    local major = llvm_major_version()
    local candidates = {
        resource_dir and path.join(resource_dir, "lib", "linux", "libclang_rt.profile-x86_64.a") or nil,
        resource_dir and path.join(resource_dir, "lib", "x86_64-unknown-linux-gnu", "libclang_rt.profile.a") or nil,
        major and path.join("/usr/lib/llvm-" .. tostring(major), "lib", "clang", tostring(major), "lib", "linux",
            "libclang_rt.profile-x86_64.a") or nil,
    }

    local runtime = _first_existing_program(candidates)
    assert(runtime, "PGO instrumentation requires libclang_rt.profile, but no usable profile runtime library was found.")
    return runtime
end

function append_runtime_toolchain_args(args)
    table.insert(args, "--cc=" .. clang_program())
    table.insert(args, "--cxx=" .. clangxx_program())
    table.insert(args, "--mm=" .. clang_program())
    table.insert(args, "--mxx=" .. clangxx_program())
    table.insert(args, "--as=" .. clang_program())
    table.insert(args, "--ld=" .. clangxx_program())
    table.insert(args, "--sh=" .. clangxx_program())
end

append_pinned_toolchain_args = append_runtime_toolchain_args

function runtime_thinlto_supported()
    local clang = _cached_lookup("clang", function ()
        return _find_first_tool({
            {toolname = "clang", program = _configured_program("cc", "mm"), opt = {version = true}},
            {toolname = "clang", opt = {version = true}},
        })
    end)
    local lld = _cached_lookup("ld.lld", function ()
        return _find_first_tool({
            {toolname = "ld.lld", program = _llvm_program_path("ld.lld"), opt = {version = true}},
            {toolname = "ld.lld", program = _llvm_versioned_program("ld.lld"), opt = {version = true}},
            {toolname = "ld.lld", opt = {version = true}},
        })
    end)
    if clang == nil or lld == nil then
        return false
    end

    local clang_major = tonumber(((clang.version or ""):match("^(%d+)")))
    local lld_major = tonumber(((lld.version or ""):match("^(%d+)")))
    return clang_major ~= nil and lld_major ~= nil and clang_major == lld_major
end

function runtime_full_lto_supported()
    return runtime_thinlto_supported()
end

function collect_configure_args(extra_args, defaults)
    defaults = defaults or {}
    local args = {"f", "--yes"}

    -- Analysis tasks should not inherit stale repo-wide config state.
    if defaults.clean ~= false then
        table.insert(args, "-c")
    end

    _append_config_arg(args, "-m", option.get("mode") or defaults.mode)
    _append_config_arg(args, "-p", option.get("plat") or defaults.plat)
    _append_config_arg(args, "-a", option.get("arch") or defaults.arch)
    _append_config_arg(args, "-o", option.get("builddir") or defaults.builddir)
    append_runtime_toolchain_args(args)

    for _, key in ipairs(runtime_config_keys) do
        local raw_value = option.get(key)
        local value = config_value_string(raw_value)
        if key == "runtime-thinlto" and value == "y" and not runtime_thinlto_supported() then
            value = "n"
        elseif key == "runtime-full-lto" and value == "y" and not runtime_full_lto_supported() then
            value = "n"
        end
        if value ~= nil and value ~= "" then
            table.insert(args, "--" .. key .. "=" .. value)
        end
    end

    _append_all(args, extra_args)
    return args
end

function taskset_program()
    local taskset = find_program("taskset")
    if taskset == nil then
        return nil
    end
    return taskset
end

function pinned_command(program, args)
    local taskset = taskset_program()
    if taskset == nil then
        return program, args
    end

    local argv = {"-c", "0", program}
    _append_all(argv, args or {})
    return taskset, argv
end

function run_xmake(args, opt)
    local argv = {}
    if option.get("verbose") then
        table.insert(argv, "-v")
    end
    if option.get("diagnosis") then
        table.insert(argv, "-D")
    end
    _append_all(argv, args)
    os.execv("xmake", argv, opt)
end

function command_output(program, args, opt)
    return os.iorunv(program, args or {}, opt)
end

function try_command_output(program, args, opt)
    local ok, result, errs = try {
        function ()
            return true, os.iorunv(program, args or {}, opt)
        end,
        catch {
            function (errors)
                return false, nil, errors
            end
        }
    }
    return ok, result, errs
end

function find_required_tool(name, message)
    local tool = find_tool(name)
    assert(tool and tool.program, message or (name .. " not found"))
    return tool
end

function find_required_program_path(preferred_path, fallback_name, message)
    local program = _first_existing_program({preferred_path, fallback_name})
    assert(program, message or (fallback_name .. " not found"))
    return program
end

function find_required_program(name, message)
    local program = find_program(name)
    assert(program, message or (name .. " not found"))
    return program
end

function target_binary(builddir, target_name, mode_name)
    return path.join(builddir, os.host(), os.arch(), mode_name or "debug", target_name .. exe_suffix())
end

function write_command_output(filename, program, args, opt)
    local exec_opt = opt or {}
    local outfile = assert(io.open(filename, "w"))
    exec_opt.stdout = outfile
    exec_opt.stderr = outfile
    local ok, errs = try {
        function ()
            os.execv(program, args, exec_opt)
            return true
        end,
        catch {
            function (errors)
                return false, errors
            end
        }
    }
    outfile:close()
    if not ok then
        raise(errs)
    end
end

function trim(value)
    local trimmed = value or ""
    trimmed = trimmed:gsub("^%s+", "")
    trimmed = trimmed:gsub("%s+$", "")
    return trimmed
end

function runtime_option_keys()
    local copy = {}
    for _, key in ipairs(runtime_config_keys) do
        table.insert(copy, key)
    end
    return copy
end

function collect_runtime_option_values(defaults)
    local values = {}
    for key, value in pairs(defaults or {}) do
        values[key] = value
    end
    for _, key in ipairs(runtime_config_keys) do
        local value = config_value_string(option.get(key))
        if value ~= nil then
            values[key] = value
        end
    end
    return values
end
