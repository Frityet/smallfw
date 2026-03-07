import("core.base.option")
import("core.project.config")
import("lib.detect.find_program")
import("lib.detect.find_tool")

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

function collect_configure_args(extra_args, defaults)
    defaults = defaults or {}
    local args = {"f", "--yes"}

    _append_config_arg(args, "-m", option.get("mode") or defaults.mode)
    _append_config_arg(args, "-p", option.get("plat") or defaults.plat)
    _append_config_arg(args, "-a", option.get("arch") or defaults.arch)
    _append_config_arg(args, "-o", option.get("builddir") or defaults.builddir)

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
        local value = config_value_string(option.get(key))
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
