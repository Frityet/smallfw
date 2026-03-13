smallfw = smallfw or {}

function smallfw.project_path(...)
    return path.join(os.projectdir(), ...)
end

function smallfw.add_runtime_boolean_option(name, description, category)
    option(name)
        set_default(false)
        set_showmenu(true)
        set_category(category)
        set_description(description)
    option_end()
end

option("objc-runtime")
    set_default("gnustep-2.3")
    set_showmenu(true)
    set_category("runtime/core")
    set_values("gnustep-2.3", "objfw-1.5")
    set_description("Select the Objective-C runtime ABI/compiler mode")
option_end()

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
    set_description("Enable defensive runtime object validation (recommended for debug/tests, disable for fastest release)")
option_end()

option("runtime-tagged-pointers")
    set_default(true)
    set_showmenu(true)
    set_category("runtime/core")
    set_description("Enable tagged pointer runtime support for user-defined classes and GNUstep NSString/NSNumber literals")
option_end()

option("analysis-symbols")
    set_default(false)
    set_showmenu(true)
    set_category("runtime/analysis")
    set_description("Internal: keep symbols in analysis/profile builds")
option_end()

option("runtime-sanitize")
    set_default(false)
    set_showmenu(true)
    set_category("runtime/analysis")
    set_description("Enable AddressSanitizer and UndefinedBehaviorSanitizer for runtime analysis builds")
option_end()

smallfw.add_runtime_boolean_option("runtime-native-tuning",
                                   "Enable -march=native and -mtune=native on supported Linux x86_64 builds.",
                                   "runtime/perf")
option("runtime-native-tuning")
    after_check(function (option)
        if option:enabled() and (not is_plat("linux") or not is_arch("x86_64")) then
            option:enable(false)
        end
    end)
option_end()

smallfw.add_runtime_boolean_option("runtime-thinlto",
                                   "Enable ThinLTO for runtime targets.",
                                   "runtime/perf")
option("runtime-thinlto")
    after_check(function (option)
        import("lib.detect.find_tool")

        local function runtime_tool_major(tool_name, program)
            local opt = {version = true}
            if program ~= nil then
                opt.program = program
            end

            local tool = find_tool(tool_name, opt)
            if tool == nil or tool.version == nil then
                return nil
            end
            return tonumber((tool.version or ""):match("^(%d+)"))
        end

        if not option:enabled() then
            return
        end
        if not is_plat("linux") or not is_arch("x86_64") then
            option:enable(false)
            return
        end

        local clang_major = runtime_tool_major("clang")
        local lld_major = runtime_tool_major("ld.lld")
        if clang_major == nil or lld_major == nil or clang_major ~= lld_major then
            option:enable(false)
        end
    end)
option_end()

smallfw.add_runtime_boolean_option("runtime-full-lto",
                                   "Enable full LTO for runtime targets.",
                                   "runtime/perf")
option("runtime-full-lto")
    after_check(function (option)
        import("lib.detect.find_tool")

        local function runtime_tool_major(tool_name, program)
            local opt = {version = true}
            if program ~= nil then
                opt.program = program
            end

            local tool = find_tool(tool_name, opt)
            if tool == nil or tool.version == nil then
                return nil
            end
            return tonumber((tool.version or ""):match("^(%d+)"))
        end

        if not option:enabled() then
            return
        end
        if not is_plat("linux") or not is_arch("x86_64") then
            option:enable(false)
            return
        end

        local clang_major = runtime_tool_major("clang")
        local lld_major = runtime_tool_major("ld.lld")
        if clang_major == nil or lld_major == nil or clang_major ~= lld_major then
            option:enable(false)
        end
    end)
option_end()

smallfw.add_runtime_boolean_option("runtime-compact-headers",
                                   "Use a compact runtime header with cold state stored out-of-line.",
                                   "runtime/abi")

smallfw.add_runtime_boolean_option("runtime-inline-value-storage",
                                   "Use compact inline prefixes for embedded ValueObjects.",
                                   "runtime/abi")
option("runtime-inline-value-storage")
    add_deps("runtime-compact-headers")
    after_check(function (option)
        local compact = option:dep("runtime-compact-headers")
        if option:enabled() and (compact == nil or not compact:enabled()) then
            option:enable(false)
        end
    end)
option_end()

smallfw.add_runtime_boolean_option("runtime-inline-group-state",
                                   "Store non-threadsafe parent/group bookkeeping inline in the root allocation.",
                                   "runtime/abi")
option("runtime-inline-group-state")
    add_deps("runtime-compact-headers")
    after_check(function (option)
        if not option:enabled() then
            return
        end
        local compact = option:dep("runtime-compact-headers")
        if compact == nil or not compact:enabled() then
            option:enable(false)
        end
    end)
option_end()

smallfw.runtime_build_options = {
    "objc-runtime",
    "dispatch-backend",
    "runtime-exceptions",
    "runtime-reflection",
    "runtime-forwarding",
    "runtime-validation",
    "runtime-tagged-pointers",
    "analysis-symbols",
    "runtime-sanitize",
    "runtime-native-tuning",
    "runtime-thinlto",
    "runtime-full-lto",
    "runtime-compact-headers",
    "runtime-inline-value-storage",
    "runtime-inline-group-state",
}
