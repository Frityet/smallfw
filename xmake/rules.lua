smallfw = smallfw or {}

local function add_objc_flags_to_target(target, ...)
    local flags = {...}
    for _, key in ipairs({"cflags", "cxflags", "mflags", "mxflags"}) do
        local values = {}
        for _, flag in ipairs(flags) do
            table.insert(values, flag)
        end
        table.insert(values, {force = true})
        target:add(key, table.unpack(values))
    end
end

local function add_objc_language_flags_to_target(target, ...)
    local flags = {...}
    for _, key in ipairs({"mflags", "mxflags"}) do
        local values = {}
        for _, flag in ipairs(flags) do
            table.insert(values, flag)
        end
        table.insert(values, {force = true})
        target:add(key, table.unpack(values))
    end
end

local function add_force_flags(target, key, ...)
    local values = {...}
    table.insert(values, {force = true})
    target:add(key, table.unpack(values))
end

local function project_is_wasm()
    return is_plat("wasm")
end

local function project_is_wasm32()
    return project_is_wasm() and is_arch("wasm32")
end

local function project_is_wasm64()
    return project_is_wasm() and is_arch("wasm64")
end

local function project_objc_runtime()
    return "gnustep-2.3"
end

local function runtime_dispatch_backend()
    if project_is_wasm() then
        return "c"
    end
    return get_config("dispatch-backend") or "asm"
end

local function runtime_lto_mode()
    if has_config("runtime-thinlto") then
        return "thin"
    end
    if has_config("runtime-full-lto") then
        return "full"
    end
    return nil
end

local function runtime_generic_metadata_enabled()
    return has_config("runtime-generic-metadata") and not project_is_wasm()
end

local function runtime_exceptions_enabled()
    return has_config("runtime-exceptions") and not project_is_wasm()
end

local function runtime_tagged_pointers_enabled()
    return has_config("runtime-tagged-pointers") and not project_is_wasm32()
end

local function module_map_paths()
    return {
        smallfw.project_path("Runtime", "SFRuntime", "src", "SFRuntime.modulemap"),
        smallfw.project_path("Runtime", "SFBlocksRuntime", "src", "SFBlocksRuntime.modulemap"),
        smallfw.project_path("StandardLibrary", "src", "SFStandardLibrary.modulemap"),
    }
end

local function target_add_runtime_mode_defines(target)
    target:add("defines", has_config("runtime-validation") and
        "SF_RUNTIME_VALIDATION=1" or "SF_RUNTIME_VALIDATION=0")
    target:add("defines", "SF_RUNTIME_THREADSAFE=0", "SF_DISPATCH_STATS=0")
    target:add("defines", is_mode("test") and "SF_RUNTIME_TESTING=1" or "SF_RUNTIME_TESTING=0", {public = true})
    target:add("defines", has_config("runtime-forwarding") and
        "SF_RUNTIME_FORWARDING=1" or "SF_RUNTIME_FORWARDING=0", {public = true})

    if runtime_dispatch_backend() == "c" then
        target:add("defines", "SF_DISPATCH_BACKEND_C=1")
    else
        target:add("defines", "SF_DISPATCH_BACKEND_ASM=1")
    end

    if runtime_exceptions_enabled() then
        target:add("defines", "SF_RUNTIME_EXCEPTIONS=1", {public = true})
        target:set("exceptions", "objc")
        add_objc_flags_to_target(target, "-fobjc-exceptions")
    else
        target:add("defines", "SF_RUNTIME_EXCEPTIONS=0", {public = true})
        target:set("exceptions", "no-objc")
    end

    target:add("defines", has_config("runtime-reflection") and
        "SF_RUNTIME_REFLECTION=1" or "SF_RUNTIME_REFLECTION=0", {public = true})
    target:add("defines", runtime_tagged_pointers_enabled() and
        "SF_RUNTIME_TAGGED_POINTERS=1" or "SF_RUNTIME_TAGGED_POINTERS=0", {public = true})
    target:add("defines", "SF_DISPATCH_L0_DUAL=0", "SF_DISPATCH_CACHE_2WAY=0", "SF_DISPATCH_CACHE_NEGATIVE=0")
    target:add("defines", has_config("runtime-compact-headers") and
        "SF_RUNTIME_COMPACT_HEADERS=1" or "SF_RUNTIME_COMPACT_HEADERS=0", {public = true})
    target:add("defines", has_config("runtime-inline-value-storage") and
        "SF_RUNTIME_INLINE_VALUE_STORAGE=1" or "SF_RUNTIME_INLINE_VALUE_STORAGE=0", {public = true})
    target:add("defines", has_config("runtime-inline-group-state") and
        "SF_RUNTIME_INLINE_GROUP_STATE=1" or "SF_RUNTIME_INLINE_GROUP_STATE=0")
    target:add("defines", runtime_generic_metadata_enabled() and
        "SF_RUNTIME_GENERIC_METADATA=1" or "SF_RUNTIME_GENERIC_METADATA=0", {public = true})
    target:add("defines", "SF_RUNTIME_SLIM_ALLOC=0")
end

function smallfw.is_wasm()
    return project_is_wasm()
end

function smallfw.is_wasm32()
    return project_is_wasm32()
end

function smallfw.is_wasm64()
    return project_is_wasm64()
end

function smallfw.objc_runtime()
    return project_objc_runtime()
end

function smallfw.runtime_dispatch_backend()
    return runtime_dispatch_backend()
end

function smallfw.runtime_lto_mode()
    return runtime_lto_mode()
end

function smallfw.runtime_binary_dependency()
    if runtime_lto_mode() == "full" then
        return "smallfw-runtime-objects"
    end
    return "smallfw-runtime"
end

function smallfw.runtime_generic_metadata_enabled()
    return runtime_generic_metadata_enabled()
end

function smallfw.runtime_exceptions_enabled()
    return runtime_exceptions_enabled()
end

function smallfw.runtime_tagged_pointers_enabled()
    return runtime_tagged_pointers_enabled()
end

rule("mode.test")
    on_load(function (target)
        target:set("symbols", "debug")
        target:set("optimize", "none")
    end)

rule("smallfw.runtime.common")
    on_load(function (target)
        target:set("warnings", "all")
        if project_is_wasm() then
            raise("wasm is disabled: Clang rejects GNUstep Objective-C runtime version 2 for wasm and ObjFW ABI support has been removed")
        end
        if project_is_wasm32() and is_mode("release") then
            target:set("optimize", "none")
        end

        if is_plat("linux") then
            target:add("defines", "_POSIX_C_SOURCE=200809L", {force = true})
        end
        if project_is_wasm64() then
            add_objc_flags_to_target(target, "-sMEMORY64=1")
        end

        add_objc_flags_to_target(target,
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
            "-Wno-c++-keyword",
            "-Wno-unused-parameter",
            "-Wno-unused-function",
            "-Wno-unused-variable",
            "-Wno-objc-root-class",
            "-Wno-objc-method-access",
            "-Wno-nullability-extension",
            "-Winvalid-offsetof")

        if is_mode("release") then
            add_objc_flags_to_target(target, "-fomit-frame-pointer")
        else
            add_objc_flags_to_target(target, "-fno-omit-frame-pointer")
        end
        if has_config("runtime-native-tuning") and is_plat("linux") and is_arch("x86_64") then
            add_objc_flags_to_target(target, "-march=native", "-mtune=native")
        end

        local lto_mode = runtime_lto_mode()
        if lto_mode ~= nil then
            add_objc_flags_to_target(target, "-flto=" .. lto_mode)
            add_force_flags(target, "ldflags", "-flto=" .. lto_mode, "-fuse-ld=lld")
        end
        if is_plat("linux") or is_plat("mingw") then
            add_objc_flags_to_target(target, "-ffunction-sections", "-fdata-sections")
        end
        if is_plat("linux") then
            add_force_flags(target, "ldflags", "-Wl,--build-id=sha1")
            if is_mode("release") then
                add_objc_flags_to_target(target, "-fno-semantic-interposition")
                add_force_flags(target, "ldflags", "-Wl,-O2", "-Wl,--gc-sections")
            end
        elseif is_plat("mingw") then
            add_force_flags(target, "ldflags", "-fuse-ld=lld")
            if is_mode("release") then
                add_force_flags(target, "ldflags", "-Wl,--gc-sections")
            end
            add_objc_flags_to_target(target, "-Wno-used-but-marked-unused")
        end

        local module_cache = path.join(target:autogendir(), "clang-module-cache")
        add_objc_language_flags_to_target(target, "-fobjc-runtime=" .. project_objc_runtime(), "-fobjc-arc", "-fblocks",
                                          "-fmodules", "-fimplicit-modules", "-fmodules-cache-path=" .. module_cache)
        for _, modulemap in ipairs(module_map_paths()) do
            if os.isfile(modulemap) then
                add_objc_language_flags_to_target(target, "-fmodule-map-file=" .. modulemap)
            end
        end
        target_add_runtime_mode_defines(target)

        if has_config("analysis-symbols") then
            target:set("symbols", "debug")
            target:set("strip", "none")
            if is_plat("linux") then
                add_force_flags(target, "ldflags", "-Wl,--emit-relocs")
            end
        end

    end)

rule("smallfw.runtime.binary")
    on_load(function (target)
        if is_plat("macosx") or is_plat("mingw") then
            target:add("links", "pthread")
        else
            target:add("links", "dl", "pthread")
        end
        if is_plat("linux") then
            add_force_flags(target, "ldflags", "-rdynamic")
        end
    end)

rule("smallfw.wasm.run")
    on_run(function (target)
        import("lib.detect.find_program")
        local node = find_program("node")
        assert(node ~= nil, "node is required to run wasm targets")
        os.execv(node, {path.absolute(target:targetfile())})
    end)

rule("smallfw.generic_metadata")
    on_load(function (target)
        if not runtime_generic_metadata_enabled() or target:name() == "smallfw-generics-plugin" then
            return
        end
        target:add("deps", "smallfw-generics-plugin", {order = true})
    end)
    after_load(function (target)
        if not runtime_generic_metadata_enabled() or target:name() == "smallfw-generics-plugin" then
            return
        end

        local plugin = target:dep("smallfw-generics-plugin")
        assert(plugin ~= nil, "smallfw-generics-plugin dependency was not created")
        local pluginfile = path.absolute(plugin:targetfile())
        assert(pluginfile ~= nil and pluginfile ~= "", "smallfw-generics-plugin target file is unavailable")
        add_force_flags(target, "mflags", "-fplugin=" .. pluginfile, "-fpass-plugin=" .. pluginfile)
        add_force_flags(target, "mxflags", "-fplugin=" .. pluginfile, "-fpass-plugin=" .. pluginfile)
    end)

rule("smallfw.wasm.test")
    on_test(function (target, opt)
        if not project_is_wasm() then
            return os.execv(target:targetfile(), opt.runargs or {}) == 0
        end

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

rule("smallfw.wasm.browser_smoke")
    after_build(function (target)
        if not project_is_wasm() then
            return
        end

        local targetfile = path.absolute(target:targetfile())
        if targetfile == nil or path.extension(targetfile) ~= ".js" then
            return
        end

        local title = target:extraconf("rules", "smallfw.wasm.browser_smoke", "title") or target:name()
        local script_name = path.filename(targetfile)
        local htmlfile = path.join(path.directory(targetfile), path.basename(targetfile) .. ".html")
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

rule("smallfw.runtime.fuzz_sanitizer")
    on_load(function (target)
        add_objc_flags_to_target(target, "-fsanitize=fuzzer,address,undefined", "-fno-sanitize-recover=all", "-fno-omit-frame-pointer")
        add_force_flags(target, "ldflags", "-fsanitize=fuzzer,address,undefined", "-fno-sanitize-recover=all")
        target:set("optimize", "none")
        target:set("symbols", "debug")
    end)
