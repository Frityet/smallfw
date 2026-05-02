smallfw = smallfw or {}

function smallfw.project_path(...)
    return path.join(os.projectdir(), ...)
end

local function runtime_tool_major(tool_name, programs)
    import("lib.detect.find_tool")

    for _, program in ipairs(programs or {}) do
        local opt = {version = true}
        if program ~= nil then
            opt.program = program
        end

        local tool = find_tool(tool_name, opt)
        if tool ~= nil and tool.version ~= nil then
            return tonumber((tool.version or ""):match("^(%d+)"))
        end
    end
    return nil
end

option("dispatch-backend")
    set_default("asm")
    set_showmenu(true)
    set_category("runtime/core")
    set_values("asm", "c")
    set_description("Select objc_msgSend backend")
option_end()

option("runtime-exceptions")
    set_default(true)
    set_showmenu(true)
    set_category("runtime/core")
    set_description("Enable Objective-C exceptions support in runtime")
    after_check(function (option)
        if option:enabled() and is_plat("wasm") then
            option:enable(false)
        end
    end)
option_end()

option("runtime-reflection")
    set_default(true)
    set_showmenu(true)
    set_category("runtime/core")
    set_description("Enable Objective-C reflection support in runtime")
option_end()

option("runtime-forwarding")
    set_default(false)
    set_showmenu(true)
    set_category("runtime/core")
    set_description("Enable message forwarding and runtime selector resolution support")
option_end()

option("runtime-validation")
    set_default(false)
    set_showmenu(true)
    set_category("runtime/core")
    set_description("Enable defensive runtime object validation")
option_end()

option("runtime-tagged-pointers")
    set_default(true)
    set_showmenu(true)
    set_category("runtime/core")
    set_description("Enable tagged pointer runtime support")
    after_check(function (option)
        if option:enabled() and is_plat("wasm") and is_arch("wasm32") then
            option:enable(false)
        end
    end)
option_end()

option("analysis-symbols")
    set_default(false)
    set_showmenu(true)
    set_category("runtime/analysis")
    set_description("Keep symbols in analysis/profile builds")
option_end()

option("runtime-native-tuning")
    set_default(false)
    set_showmenu(true)
    set_category("runtime/perf")
    set_description("Enable -march=native and -mtune=native on supported Linux x86_64 builds")
    after_check(function (option)
        if option:enabled() and (not is_plat("linux") or not is_arch("x86_64")) then
            option:enable(false)
        end
    end)
option_end()

option("runtime-thinlto")
    set_default(false)
    set_showmenu(true)
    set_category("runtime/perf")
    set_description("Enable ThinLTO for runtime targets")
    after_check(function (option)
        if not option:enabled() then
            return
        end
        if not is_plat("linux") or not is_arch("x86_64") then
            option:enable(false)
            return
        end

        local clang_major = runtime_tool_major("clang", {get_config("cc"), get_config("mm"), "clang"})
        local lld_major = runtime_tool_major("ld.lld", {"ld.lld"})
        if clang_major == nil or lld_major == nil or clang_major ~= lld_major then
            option:enable(false)
        end
    end)
option_end()

option("runtime-full-lto")
    set_default(false)
    set_showmenu(true)
    set_category("runtime/perf")
    set_description("Enable full LTO for runtime targets")
    after_check(function (option)
        if not option:enabled() then
            return
        end
        if not is_plat("linux") or not is_arch("x86_64") then
            option:enable(false)
            return
        end

        local clang_major = runtime_tool_major("clang", {get_config("cc"), get_config("mm"), "clang"})
        local lld_major = runtime_tool_major("ld.lld", {"ld.lld"})
        if clang_major == nil or lld_major == nil or clang_major ~= lld_major then
            option:enable(false)
        end
    end)
option_end()

option("runtime-compact-headers")
    set_default(false)
    set_showmenu(true)
    set_category("runtime/abi")
    set_description("Use a compact runtime header with cold state stored out-of-line")
option_end()

option("runtime-inline-value-storage")
    set_default(false)
    set_showmenu(true)
    set_category("runtime/abi")
    set_description("Use compact inline prefixes for embedded ValueObjects")
    add_deps("runtime-compact-headers")
    after_check(function (option)
        local compact = option:dep("runtime-compact-headers")
        if option:enabled() and (compact == nil or not compact:enabled()) then
            option:enable(false)
        end
    end)
option_end()

option("runtime-inline-group-state")
    set_default(false)
    set_showmenu(true)
    set_category("runtime/abi")
    set_description("Store non-threadsafe parent/group bookkeeping inline in the root allocation")
    add_deps("runtime-compact-headers")
    after_check(function (option)
        local compact = option:dep("runtime-compact-headers")
        if option:enabled() and (compact == nil or not compact:enabled()) then
            option:enable(false)
        end
    end)
option_end()

option("runtime-generic-metadata")
    set_default(false)
    set_showmenu(true)
    set_category("runtime/experimental")
    set_description("Enable the SmallFW generics compiler/pass plugin")
    after_check(function (option)
        if not option:enabled() then
            return
        end
        if is_plat("wasm") or not is_plat("linux") then
            option:enable(false)
            return
        end

        local clang_major = runtime_tool_major("clang", {get_config("mm"), get_config("cc"), "clang-21", "clang"})
        local opt_major = runtime_tool_major("opt", {"opt-21", "opt"})
        local llvm_config_major = runtime_tool_major("llvm-config", {"llvm-config-21", "llvm-config"})
        if clang_major ~= 21 or opt_major ~= 21 or llvm_config_major ~= 21 then
            option:enable(false)
        end
    end)
option_end()

smallfw.runtime_build_options = {
    "dispatch-backend",
    "runtime-exceptions",
    "runtime-reflection",
    "runtime-forwarding",
    "runtime-validation",
    "runtime-tagged-pointers",
    "analysis-symbols",
    "runtime-native-tuning",
    "runtime-thinlto",
    "runtime-full-lto",
    "runtime-compact-headers",
    "runtime-inline-value-storage",
    "runtime-inline-group-state",
    "runtime-generic-metadata",
}
