import("core.base.option")
import("smallfw.task_helpers")

local function _string_option(name, default_value)
    local value = option.get(name)
    if value == nil or value == "" then
        return default_value
    end
    return value
end

function main()
    local mode_name = _string_option("mode", "debug")
    local builddir = _string_option("builddir", path.join("build", "runtime-analysis", "sanitize"))
    local case_name = _string_option("case", nil)
    local configure_args = task_helpers.collect_configure_args({
        "--analysis-symbols=y",
        "--runtime-validation=y",
        "--runtime-sanitize=y",
    }, {mode = mode_name, plat = "linux", arch = "x86_64", builddir = builddir})
    local argv = {}

    task_helpers.run_xmake(configure_args)
    task_helpers.run_xmake({"b", "runtime-tests"})

    if case_name ~= nil then
        table.insert(argv, "--case")
        table.insert(argv, case_name)
    else
        table.insert(argv, "--all")
    end

    os.execv(task_helpers.target_binary(builddir, "runtime-tests", mode_name), argv, {
        envs = {
            ASAN_OPTIONS = "detect_leaks=0:abort_on_error=1",
            UBSAN_OPTIONS = "halt_on_error=1:print_stacktrace=1",
        },
    })
end
