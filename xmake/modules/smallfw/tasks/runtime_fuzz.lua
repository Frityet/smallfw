import("core.base.option")
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

local function _fuzz_target_name(name)
    local targets = {
        dispatch = "runtime_fuzz_dispatch",
        loader = "runtime_fuzz_loader",
        exceptions = "runtime_fuzz_exceptions",
    }
    local target = targets[name]
    assert(target ~= nil, "unknown fuzz target: " .. tostring(name))
    return target
end

function main()
    local mode_name = _string_option("mode", "debug")
    local builddir = _string_option("builddir", path.join("build", "runtime-analysis", "fuzz"))
    local target = _fuzz_target_name(_string_option("target", "dispatch"))
    local runs = _positive_integer_option("runs", 10000)
    local corpus = _string_option("corpus", nil)
    local configure_args = task_helpers.collect_configure_args({
        "--analysis_symbols=y",
        "--runtime_validation=y",
        "--runtime_sanitize=y",
        "--dispatch_backend=c",
    }, {mode = mode_name, plat = "linux", arch = "x86_64", builddir = builddir})

    task_helpers.run_xmake(configure_args)
    task_helpers.run_xmake({"b", target})

    local binary = task_helpers.target_binary(builddir, target, mode_name)
    local argv = {string.format("-runs=%d", runs)}
    if corpus ~= nil then
        os.mkdir(corpus)
        table.insert(argv, corpus)
    end
    os.execv(binary, argv, {
        envs = {
            ASAN_OPTIONS = "detect_leaks=0:abort_on_error=1",
            UBSAN_OPTIONS = "halt_on_error=1:print_stacktrace=1",
        },
    })
end
