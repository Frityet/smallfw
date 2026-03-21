smallfw = smallfw or {}

local release_clang_tidy_ran = false

local function add_objc_flags(...)
    local flags = {...}
    table.insert(flags, {force = true})
    add_cflags(flags)
    add_cxflags(flags)
    add_mflags(flags)
    add_mxflags(flags)
end

function smallfw.runtime_dispatch_backend()
    if smallfw.is_wasm() then
        return "c"
    end
    return get_config("dispatch-backend") or "asm"
end

function smallfw.is_wasm()
    return is_plat("wasm")
end

function smallfw.is_wasm32()
    return smallfw.is_wasm() and is_arch("wasm32")
end

function smallfw.is_wasm64()
    return smallfw.is_wasm() and is_arch("wasm64")
end

function smallfw.objc_runtime()
    if smallfw.is_wasm() then
        return "objfw-1.5"
    end
    return get_config("objc-runtime") or "gnustep-2.3"
end

function smallfw.objc_runtime_is_gnustep()
    return smallfw.objc_runtime() == "gnustep-2.3"
end

function smallfw.objc_runtime_is_objfw()
    return smallfw.objc_runtime() == "objfw-1.5"
end

function smallfw.runtime_lto_mode()
    local thin = has_config("runtime-thinlto")
    local full = has_config("runtime-full-lto")
    if thin then
        return "thin"
    end
    if full then
        return "full"
    end
    return nil
end

function smallfw.runtime_binary_dependency()
    if smallfw.runtime_lto_mode() == "full" then
        return "smallfw-runtime-objects"
    end
    return "smallfw-runtime"
end

function smallfw.runtime_generic_metadata_enabled()
    return has_config("runtime-generic-metadata") and not smallfw.is_wasm()
end

function smallfw.runtime_exceptions_enabled()
    return has_config("runtime-exceptions") and not smallfw.is_wasm()
end

function smallfw.runtime_tagged_pointers_enabled()
    return has_config("runtime-tagged-pointers") and not smallfw.is_wasm32()
end

function smallfw.node_program()
    import("lib.detect.find_program")

    local node = find_program("node")
    assert(node ~= nil, "node is required to run wasm targets")
    return node
end

function smallfw.add_wasm_binary_settings()
    if not smallfw.is_wasm() then
        return
    end

    set_extension(".js")
    if smallfw.is_wasm64() then
        add_ldflags("-sMEMORY64=1", {force = true})
    end
    add_ldflags(
        "-sENVIRONMENT=web,node",
        "-sWASM_BIGINT=1",
        "-sDEFAULT_LIBRARY_FUNCS_TO_INCLUDE=$stackAlloc",
        {force = true}
    )
end

function smallfw.add_wasm_node_run_script()
    if not smallfw.is_wasm() then
        return
    end

    on_run(function (target)
        import("lib.detect.find_program")

        local node = find_program("node")
        assert(node ~= nil, "node is required to run wasm targets")
        os.execv(node, {path.absolute(target:targetfile())})
    end)
end

function smallfw.add_wasm_node_test_script()
    if not smallfw.is_wasm() then
        return
    end

    on_test(function (target, opt)
        import("lib.detect.find_program")

        local node = find_program("node")
        assert(node ~= nil, "node is required to run wasm targets")
        local argv = {path.absolute(target:targetfile())}
        for _, arg in ipairs(opt.runargs or {}) do
            table.insert(argv, arg)
        end

        local ok, errors = pcall(function ()
            os.execv(node, argv)
        end)
        if ok then
            return true
        end
        return false, errors
    end)
end

function smallfw.add_wasm_browser_smoke_page(opt)
    opt = opt or {}
    if not smallfw.is_wasm() then
        return
    end

    after_build(function (target)
        local targetfile = path.absolute(target:targetfile())
        if targetfile == nil or path.extension(targetfile) ~= ".js" then
            return
        end

        local htmlfile = path.join(path.directory(targetfile), path.basename(targetfile) .. ".html")
        local title = opt.title or target:name()
        local script_name = path.filename(targetfile)
        io.writefile(htmlfile, string.format([[
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>%s</title>
</head>
<body>
<pre>Open the developer console to inspect target output.</pre>
<script src="%s"></script>
</body>
</html>
]], title, script_name))
    end)
end

function smallfw.add_generic_plugin_settings()
    if not smallfw.runtime_generic_metadata_enabled() then
        return
    end

    add_deps("smallfw-generics-plugin", {order = true})
    after_load(function (target)
        if target:name() == "smallfw-generics-plugin" then
            return
        end

        local plugin = target:dep("smallfw-generics-plugin")
        assert(plugin ~= nil, "smallfw-generics-plugin dependency was not created")
        local pluginfile = path.absolute(plugin:targetfile())
        assert(pluginfile ~= nil and pluginfile ~= "", "smallfw-generics-plugin target file is unavailable")

        local frontend_flags = {
            "-fplugin=" .. pluginfile,
            "-fpass-plugin=" .. pluginfile,
        }

        local function add_flagset(key)
            local args = {}
            for _, flag in ipairs(frontend_flags) do
                table.insert(args, flag)
            end
            table.insert(args, {force = true})
            target:add(key, table.unpack(args))
        end

        add_flagset("mflags")
        add_flagset("mxflags")
    end)
end

function smallfw.add_common_runtime_flags()
    set_warnings("all")
    if smallfw.is_wasm32() and is_mode("release") then
        set_optimize("none")
    end
    if smallfw.objc_runtime_is_objfw() and not is_plat("linux") and not smallfw.is_wasm() then
        raise("objc-runtime=objfw-1.5 is only supported on linux and wasm")
    end
    if is_plat("linux") then
        add_defines("_POSIX_C_SOURCE=200809L", {force = true})
    end
    if smallfw.is_wasm() then
        if smallfw.is_wasm64() then
            add_objc_flags("-sMEMORY64=1")
        end
    end

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
        "-Wno-c23-extensions",
        "-Wno-c2x-extensions",
        "-Wno-pre-c11-compat",
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
        "-Wno-keyword-macro",
        "-Wno-c++-keyword"
    )
    if is_mode("release") then
        add_objc_flags("-fomit-frame-pointer")
    else
        add_objc_flags("-fno-omit-frame-pointer")
    end
    if has_config("runtime-native-tuning") and is_plat("linux") and is_arch("x86_64") then
        add_objc_flags("-march=native", "-mtune=native")
    end
    local lto_mode = smallfw.runtime_lto_mode()
    if lto_mode ~= nil then
        add_objc_flags("-flto=" .. lto_mode)
        add_ldflags("-flto=" .. lto_mode, "-fuse-ld=lld", {force = true})
    end
    if is_plat("linux") or is_plat("mingw") then
        add_objc_flags("-ffunction-sections", "-fdata-sections")
    end
    if is_plat("linux") then
        add_ldflags("-Wl,--build-id=sha1", {force = true})
        if is_mode("release") then
            add_objc_flags("-fno-semantic-interposition")
            add_ldflags("-Wl,-O2", "-Wl,--gc-sections", {force = true})
        end
    elseif is_plat("mingw") then
        add_ldflags("-fuse-ld=lld", {force = true})
        if is_mode("release") then
            add_ldflags("-Wl,--gc-sections", {force = true})
        end
    end
    add_objc_flags("-fobjc-runtime=" .. smallfw.objc_runtime(), "-fobjc-arc", "-fblocks")
    add_objc_flags("-Wno-unused-parameter", "-Wno-unused-function", "-Wno-unused-variable")
    add_objc_flags("-Wno-objc-root-class", "-Wno-objc-method-access", "-Winvalid-offsetof")
    add_objc_flags("-Wno-nullability-extension")
    if is_plat("mingw") then
        add_objc_flags("-Wno-used-but-marked-unused")
    end
end

function smallfw.add_runtime_mode_defines()
    if smallfw.objc_runtime_is_objfw() then
        add_defines("SF_RUNTIME_OBJC_FRAMEWORK_OBJFW=1")
    else
        add_defines("SF_RUNTIME_OBJC_FRAMEWORK_OBJFW=0")
    end

    if has_config("runtime-validation") then
        add_defines("SF_RUNTIME_VALIDATION=1")
    else
        add_defines("SF_RUNTIME_VALIDATION=0")
    end

    add_defines("SF_RUNTIME_THREADSAFE=0")
    add_defines("SF_DISPATCH_STATS=0")

    if has_config("runtime-forwarding") then
        add_defines("SF_RUNTIME_FORWARDING=1", {public = true})
    else
        add_defines("SF_RUNTIME_FORWARDING=0", {public = true})
    end

    if smallfw.runtime_dispatch_backend() == "c" then
        add_defines("SF_DISPATCH_BACKEND_C=1")
    else
        add_defines("SF_DISPATCH_BACKEND_ASM=1")
    end

    if smallfw.runtime_exceptions_enabled() then
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

    if smallfw.runtime_tagged_pointers_enabled() then
        add_defines("SF_RUNTIME_TAGGED_POINTERS=1", {public = true})
    else
        add_defines("SF_RUNTIME_TAGGED_POINTERS=0", {public = true})
    end
    add_defines("SF_DISPATCH_L0_DUAL=0")
    add_defines("SF_DISPATCH_CACHE_2WAY=0")
    add_defines("SF_DISPATCH_CACHE_NEGATIVE=0")
    if has_config("runtime-compact-headers") then
        add_defines("SF_RUNTIME_COMPACT_HEADERS=1", {public = true})
    else
        add_defines("SF_RUNTIME_COMPACT_HEADERS=0", {public = true})
    end
    if has_config("runtime-inline-value-storage") then
        add_defines("SF_RUNTIME_INLINE_VALUE_STORAGE=1", {public = true})
    else
        add_defines("SF_RUNTIME_INLINE_VALUE_STORAGE=0", {public = true})
    end
    if has_config("runtime-inline-group-state") then
        add_defines("SF_RUNTIME_INLINE_GROUP_STATE=1")
    else
        add_defines("SF_RUNTIME_INLINE_GROUP_STATE=0")
    end
    if smallfw.runtime_generic_metadata_enabled() then
        add_defines("SF_RUNTIME_GENERIC_METADATA=1", {public = true})
    else
        add_defines("SF_RUNTIME_GENERIC_METADATA=0", {public = true})
    end
    add_defines("SF_RUNTIME_SLIM_ALLOC=0")
end

function smallfw.add_analysis_symbol_settings()
    if has_config("analysis-symbols") then
        set_symbols("debug")
        set_strip("none")
        if is_plat("linux") then
            add_ldflags("-Wl,--emit-relocs", {force = true})
        end
    end
end

function smallfw.add_runtime_sanitizer_settings()
    if has_config("runtime-sanitize") then
        add_objc_flags("-fsanitize=address,undefined", "-fno-sanitize-recover=all", "-fno-omit-frame-pointer")
        add_ldflags("-fsanitize=address,undefined", "-fno-sanitize-recover=all", {force = true})
        set_optimize("none")
        set_symbols("debug")
    end
end

function smallfw.add_fuzz_sanitizer_settings()
    add_objc_flags("-fsanitize=fuzzer,address,undefined", "-fno-sanitize-recover=all", "-fno-omit-frame-pointer")
    add_ldflags("-fsanitize=fuzzer,address,undefined", "-fno-sanitize-recover=all", {force = true})
    set_optimize("none")
    set_symbols("debug")
end

function smallfw.add_release_clang_tidy_hook()
    if not is_mode("release") then
        return
    end

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

function smallfw.add_runtime_binary_links()
    if smallfw.is_wasm() then
        return
    end
    if is_plat("mingw") then
        add_links("pthread")
    else
        add_links("dl", "pthread")
    end
end

function smallfw.configure_runtime_library_target()
    set_kind("static")
    if is_mode("release") then
        set_optimize("fastest")
    end
    add_options(smallfw.runtime_build_options)
    add_deps("smallfw-blocksruntime")
    add_includedirs(smallfw.project_path("src"), {public = true})
    smallfw.add_common_runtime_flags()
    smallfw.add_generic_plugin_settings()
    smallfw.add_runtime_mode_defines()
    smallfw.add_analysis_symbol_settings()
    smallfw.add_runtime_sanitizer_settings()
end

function smallfw.configure_runtime_binary_target(opt)
    opt = opt or {}

    set_kind(opt.kind or "binary")
    smallfw.add_wasm_binary_settings()
    if opt.default ~= nil then
        set_default(opt.default)
    else
        set_default(false)
    end
    if is_mode("release") and opt.optimize ~= false then
        set_optimize("fastest")
    end

    add_options(smallfw.runtime_build_options)
    for _, dep in ipairs(opt.deps or {smallfw.runtime_binary_dependency()}) do
        add_deps(dep)
    end
    for _, includedir in ipairs(opt.includedirs or {smallfw.project_path("src")}) do
        add_includedirs(includedir)
    end

    smallfw.add_common_runtime_flags()
    smallfw.add_generic_plugin_settings()
    smallfw.add_runtime_mode_defines()
    smallfw.add_analysis_symbol_settings()
    smallfw.add_runtime_sanitizer_settings()
    if opt.fuzz_sanitizer then
        smallfw.add_fuzz_sanitizer_settings()
    end
    if opt.release_clang_tidy then
        smallfw.add_release_clang_tidy_hook()
    end
    if opt.add_links ~= false then
        smallfw.add_runtime_binary_links()
    end
    smallfw.add_wasm_node_run_script()
end

if is_plat("linux") then
    add_ldflags("-rdynamic", {force = true})
end
