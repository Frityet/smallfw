add_rules("mode.debug", "mode.release")

set_languages("gnulatest")
set_toolchains("clang")
set_policy("check.auto_ignore_flags", false)
add_moduledirs(path.join(os.projectdir(), "xmake/modules"))

option("runtime-threadsafe")
    set_default(false)
    set_showmenu(true)
    set_description("Enable synchronized runtime internals")
option_end()

option("dispatch-backend")
    set_default("asm")
    set_showmenu(true)
    set_values("asm", "c")
    set_description("Select objc_msgSend backend")
option_end()

option("dispatch-stats")
    set_default(false)
    set_showmenu(true)
    set_description("Enable dispatch cache stats counters")
option_end()

option("runtime-exceptions")
    set_default(true)
    set_showmenu(true)
    set_description("Enable Objective-C exceptions support in runtime")
option_end()

option("runtime-reflection")
    set_default(true)
    set_showmenu(true)
    set_description("Enable Objective-C reflection support in runtime")
option_end()

option("runtime-forwarding")
    set_default(false)
    set_showmenu(true)
    set_description("Enable message forwarding and runtime selector resolution support")
option_end()

option("runtime-validation")
    set_default(false)
    set_showmenu(true)
    set_description("Enable defensive runtime object validation (recommended for debug/tests, disable for fastest release)")
option_end()

option("runtime-tagged-pointers")
    set_default(false)
    set_showmenu(true)
    set_description("Enable tagged pointer runtime support for user-defined classes")
option_end()

option("analysis-symbols")
    set_default(false)
    set_showmenu(true)
    set_description("Internal: keep symbols in analysis/profile builds")
option_end()

option("runtime-sanitize")
    set_default(false)
    set_showmenu(true)
    set_description("Enable AddressSanitizer and UndefinedBehaviorSanitizer for runtime analysis builds")
option_end()

local objc_runtime = "gnustep-2.3"

local function add_objc_flags(...)
    local flags = {...}
    table.insert(flags, {force = true})
    add_cflags(table.unpack(flags))
    add_cxflags(table.unpack(flags))
    add_mflags(table.unpack(flags))
    add_mxflags(table.unpack(flags))
end

local function add_common_runtime_flags()
    set_warnings("everything", "error")

    -- Suppressions allowlist kept intentionally small for runtime ABI portability.
    add_objc_flags(
        "-Wpedantic",
        "-Wconversion",
        "-Wsign-conversion",
        "-Wstrict-prototypes",
        "-Wnullability-completeness",
        "-Wnullable-to-nonnull-conversion",
        "-Wnull-dereference",
        "-Wshadow-all",
        "-Wdouble-promotion",
        "-Wcast-align",
        "-Wstrict-selector-match",
        "-Wundef",
        "-Wformat=2",
        "-Wdocumentation",
        "-Wnullability",
        "-Wno-c++98-compat",
        "-Wno-c++98-compat-pedantic",
        "-Wno-pre-c23-compat",
        "-Wno-pre-c2x-compat",
        "-Wno-nullability-extension",
        "-Wno-covered-switch-default",
        "-Wno-disabled-macro-expansion",
        "-Wno-declaration-after-statement",
        "-Wno-padded",
        "-Wno-reserved-identifier",
        "-Wno-reserved-macro-identifier",
        "-Wno-cast-function-type-mismatch",
        "-Wno-cast-function-type-strict",
        "-Wno-direct-ivar-access",
        "-Wno-objc-interface-ivars",
        "-Wno-unsafe-buffer-usage",
        "-Wno-c++-keyword"
    )
    if is_mode("release") then
        add_objc_flags("-fomit-frame-pointer")
    else
        add_objc_flags("-fno-omit-frame-pointer")
    end
    add_objc_flags("-fobjc-runtime=" .. objc_runtime, "-fobjc-arc")
    add_objc_flags("-Wno-unused-parameter", "-Wno-unused-function", "-Wno-unused-variable")
    add_objc_flags("-Wno-objc-root-class", "-Wno-objc-method-access", "-Winvalid-offsetof")
    if is_plat("mingw") then
        add_objc_flags("-Wno-used-but-marked-unused")
    end
end

local function add_runtime_mode_defines()
    if has_config("runtime-validation") then
        add_defines("SF_RUNTIME_VALIDATION=1")
    else
        add_defines("SF_RUNTIME_VALIDATION=0")
    end

    if has_config("runtime-threadsafe") then
        add_defines("SF_RUNTIME_THREADSAFE=1")
        add_syslinks("pthread")
    else
        add_defines("SF_RUNTIME_THREADSAFE=0")
    end

    if has_config("dispatch-stats") then
        add_defines("SF_DISPATCH_STATS=1")
    else
        add_defines("SF_DISPATCH_STATS=0")
    end

    if has_config("runtime-forwarding") then
        add_defines("SF_RUNTIME_FORWARDING=1", {public = true})
    else
        add_defines("SF_RUNTIME_FORWARDING=0", {public = true})
    end

    local backend = get_config("dispatch-backend") or "asm"
    if backend == "c" then
        add_defines("SF_DISPATCH_BACKEND_C=1")
    else
        add_defines("SF_DISPATCH_BACKEND_ASM=1")
    end

    if has_config("runtime-exceptions") then
        add_defines("SF_RUNTIME_EXCEPTIONS=1", {public = true})
        set_exceptions("objc")
        add_objc_flags("-fobjc-exceptions")
    else
        add_defines("SF_RUNTIME_EXCEPTIONS=0", {public = true})
        set_exceptions("no-objc")
    end

    if has_config("runtime-reflection") then
        add_defines("SF_RUNTIME_REFLECTION=1", {public = true})
    else
        add_defines("SF_RUNTIME_REFLECTION=0", {public = true})
    end

    if has_config("runtime-tagged-pointers") then
        add_defines("SF_RUNTIME_TAGGED_POINTERS=1", {public = true})
    else
        add_defines("SF_RUNTIME_TAGGED_POINTERS=0", {public = true})
    end

        add_defines("SF_RUNTIME_SLIM_ALLOC=0")

end

local function add_analysis_symbol_settings()
    if has_config("analysis-symbols") then
        set_symbols("debug")
        set_strip("none")
    end
end

local function add_runtime_sanitizer_settings()
    if has_config("runtime-sanitize") then
        add_objc_flags("-fsanitize=address,undefined", "-fno-sanitize-recover=all", "-fno-omit-frame-pointer")
        add_ldflags("-fsanitize=address,undefined", "-fno-sanitize-recover=all", {force = true})
        set_optimize("none")
        set_symbols("debug")
    end
end

local function add_fuzz_sanitizer_settings()
    add_objc_flags("-fsanitize=fuzzer,address,undefined", "-fno-sanitize-recover=all", "-fno-omit-frame-pointer")
    add_ldflags("-fsanitize=fuzzer,address,undefined", "-fno-sanitize-recover=all", {force = true})
    set_optimize("none")
    set_symbols("debug")
end

local release_clang_tidy_ran = false

local function add_release_clang_tidy_hook()
    if not is_mode("release") then
        return
    end

    add_rules("plugin.compile_commands.autoupdate")
    after_build(function (_)
        if release_clang_tidy_ran or os.getenv("SMALLFW_SKIP_RELEASE_CLANG_TIDY") == "1" then
            return
        end

        release_clang_tidy_ran = true
        local exec_opt = {envs = {SMALLFW_SKIP_RELEASE_CLANG_TIDY = "1"}}
        print("Running clang-tidy for release build")
        os.execv("xmake", {"check", "clang.tidy", "smallfw-runtime"}, exec_opt)
    end)
end

if is_plat("linux") then
    add_ldflags("-rdynamic", {force = true})
elseif is_plat("mingw") then
    add_ldflags("-fuse-ld=lld", {force = true})
end

local dispatch_backend = get_config("dispatch-backend") or "asm"

target("smallfw-runtime")
    set_kind("static")
    if is_mode("release") then
        set_optimize("fastest")
    end
    add_options("runtime-threadsafe", "dispatch-backend", "dispatch-stats", "runtime-exceptions", "runtime-reflection", "runtime-forwarding", "runtime-validation", "runtime-tagged-pointers", "analysis-symbols", "runtime-sanitize")
    add_includedirs("src", {public = true})
    add_common_runtime_flags()
    add_runtime_mode_defines()
    add_analysis_symbol_settings()
    add_runtime_sanitizer_settings()

    add_files(
        "src/runtime/allocator.c",
        "src/runtime/arc.c",
        "src/runtime/dispatch.c",
        "src/runtime/exceptions.c",
        "src/runtime/helpers.c",
        "src/runtime/loader.c"
    )
    add_files("src/runtime/testhooks.c")
    if is_plat("mingw") and has_config("runtime-exceptions") then
        add_files("src/runtime/exceptions_mingw.mm", {mxflags = {"-fno-objc-arc"}})
    end

    if dispatch_backend == "asm" then
        if is_arch("x86_64") then
            if is_plat("mingw") then
                add_files("src/runtime/dispatch_c.c")
            else
                add_files("src/runtime/dispatch_x86_64.asm", {sourcekind = "as", asflags = {"-x", "assembler-with-cpp"}})
            end
        else
            add_files("src/runtime/dispatch_c.c")
            if not is_plat("mingw") then
                add_links("ffi", {public = true})
            end
        end
    else
        add_files("src/runtime/dispatch_c.c")
        if not is_plat("mingw") then
            add_links("ffi", {public = true})
        end
    end

    add_files("src/smallfw/**.m", {mflags = {"-fno-objc-arc"}})

target("runtime-tests")
    set_kind("binary")
    set_default(false)
    if is_mode("release") then
        set_optimize("fastest")
    end
    add_options("runtime-threadsafe", "dispatch-backend", "dispatch-stats", "runtime-exceptions", "runtime-reflection", "runtime-forwarding", "runtime-validation", "runtime-tagged-pointers", "analysis-symbols", "runtime-sanitize")
    add_deps("smallfw-runtime")
    add_includedirs("src", "tests")
    add_common_runtime_flags()
    add_runtime_mode_defines()
    add_analysis_symbol_settings()
    add_runtime_sanitizer_settings()
    add_release_clang_tidy_hook()
    add_files("tests/runtime_tests.m", "tests/runtime_test_*.m")
    if is_plat("mingw") then
        add_links("pthread")
    else
        add_links("dl", "pthread")
    end
    add_tests("runtime_all", {runargs = {"--all"}})

target("runtime-bench")
    set_kind("binary")
    set_default(false)
    if is_mode("release") then
        set_optimize("fastest")
    end
    add_options("runtime-threadsafe", "dispatch-backend", "dispatch-stats", "runtime-exceptions", "runtime-reflection", "runtime-forwarding", "runtime-validation", "runtime-tagged-pointers", "analysis-symbols", "runtime-sanitize")
    add_deps("smallfw-runtime")
    add_includedirs("src", "tests")
    add_common_runtime_flags()
    add_runtime_mode_defines()
    add_analysis_symbol_settings()
    add_runtime_sanitizer_settings()
    add_release_clang_tidy_hook()
    add_files("tests/runtime_bench.m")
    if is_plat("mingw") then
        add_links("pthread")
    else
        add_links("dl", "pthread")
    end

target("value-object-demo")
    set_kind("binary")
    set_default(false)
    if is_mode("release") then
        set_optimize("fastest")
    end
    add_options("runtime-threadsafe", "dispatch-backend", "dispatch-stats", "runtime-exceptions", "runtime-reflection", "runtime-forwarding", "runtime-validation", "runtime-tagged-pointers", "analysis-symbols", "runtime-sanitize")
    add_deps("smallfw-runtime")
    add_includedirs("src")
    add_common_runtime_flags()
    add_runtime_mode_defines()
    add_analysis_symbol_settings()
    add_runtime_sanitizer_settings()
    add_release_clang_tidy_hook()
    add_files("test.m")
    if is_plat("mingw") then
        add_links("pthread")
    else
        add_links("dl", "pthread")
    end

if not is_plat("mingw") then
    target("runtime-fuzz-dispatch")
        set_kind("binary")
        set_default(false)
        add_options("runtime-threadsafe", "dispatch-backend", "dispatch-stats", "runtime-exceptions", "runtime-reflection", "runtime-forwarding", "runtime-validation", "runtime-tagged-pointers", "analysis-symbols", "runtime-sanitize")
        add_deps("smallfw-runtime")
        add_includedirs("src", "tests")
        add_common_runtime_flags()
        add_runtime_mode_defines()
        add_analysis_symbol_settings()
        add_runtime_sanitizer_settings()
        add_fuzz_sanitizer_settings()
        add_release_clang_tidy_hook()
        add_files("tests/fuzz_dispatch_parser.c")
        add_links("dl", "pthread")

    target("runtime-fuzz-loader")
        set_kind("binary")
        set_default(false)
        add_options("runtime-threadsafe", "dispatch-backend", "dispatch-stats", "runtime-exceptions", "runtime-reflection", "runtime-forwarding", "runtime-validation", "runtime-tagged-pointers", "analysis-symbols", "runtime-sanitize")
        add_deps("smallfw-runtime")
        add_includedirs("src", "tests")
        add_common_runtime_flags()
        add_runtime_mode_defines()
        add_analysis_symbol_settings()
        add_runtime_sanitizer_settings()
        add_fuzz_sanitizer_settings()
        add_release_clang_tidy_hook()
        add_files("tests/fuzz_loader_layout.c")
        add_links("dl", "pthread")

    target("runtime-fuzz-exceptions")
        set_kind("binary")
        set_default(false)
        add_options("runtime-threadsafe", "dispatch-backend", "dispatch-stats", "runtime-exceptions", "runtime-reflection", "runtime-forwarding", "runtime-validation", "runtime-tagged-pointers", "analysis-symbols", "runtime-sanitize")
        add_deps("smallfw-runtime")
        add_includedirs("src", "tests")
        add_common_runtime_flags()
        add_runtime_mode_defines()
        add_analysis_symbol_settings()
        add_runtime_sanitizer_settings()
        add_fuzz_sanitizer_settings()
        add_release_clang_tidy_hook()
        add_files("tests/fuzz_exceptions_lsda.c")
        add_links("dl", "pthread")
end

includes("xmake/tasks/common.lua")
includes("xmake/tasks/runtime_bench.lua")
includes("xmake/tasks/runtime_coverage.lua")
includes("xmake/tasks/runtime_fuzz.lua")
includes("xmake/tasks/runtime_profile.lua")
includes("xmake/tasks/runtime_sanitize.lua")
includes("xmake/tasks/scan_build.lua")
