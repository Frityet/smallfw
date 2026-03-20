local plugin_test_includedirs = {
    smallfw.project_path(),
    smallfw.project_path("src"),
}

target("plugin-generic-metadata-checks")
    set_group("tests/plugins")
    smallfw.configure_runtime_binary_target({
        includedirs = plugin_test_includedirs,
    })
    add_files("plugin_checks_stub.m")
    add_tests("plugin-generic-metadata-checks", {
        group = "plugins/generic-metadata",
        realtime_output = true,
    })
    on_test(function (target)
        import("lib.detect.find_program")

        local mflags = table.concat(target:get("mflags") or {}, "\n")
        local mxflags = table.concat(target:get("mxflags") or {}, "\n")
        if not has_config("runtime-generic-metadata") then
            assert(mflags:find("-fplugin=", 1, true) == nil,
                   "generic metadata plugin flags should be absent when runtime-generic-metadata=n")
            assert(mxflags:find("-fplugin=", 1, true) == nil,
                   "Objective-C++ generic metadata plugin flags should be absent when runtime-generic-metadata=n")
            return
        end

        assert(mflags:find("-fplugin=", 1, true) ~= nil,
               "clang frontend plugin flag missing when runtime-generic-metadata=y")
        assert(mxflags:find("-fplugin=", 1, true) ~= nil,
               "Objective-C++ clang frontend plugin flag missing when runtime-generic-metadata=y")
        assert(mflags:find("-fpass-plugin=", 1, true) ~= nil,
               "LLVM pass plugin flag missing when runtime-generic-metadata=y")
        assert(mxflags:find("-fpass-plugin=", 1, true) ~= nil,
               "Objective-C++ LLVM pass plugin flag missing when runtime-generic-metadata=y")

        local plugin_target = target:dep("smallfw-generics-plugin")
        assert(plugin_target ~= nil, "smallfw-generics-plugin dependency missing when runtime-generic-metadata=y")

        local clang = find_program("clang-21") or find_program("clang")
        assert(clang ~= nil, "clang is required for plugin IR verification")

        local plugin = path.absolute(plugin_target:targetfile())
        local projectdir = os.projectdir()
        local source = path.join(projectdir, "tests", "plugins", "generic_ir_check.m")
        local ir = os.iorunv(clang, {
            "-S",
            "-emit-llvm",
            "-O0",
            "-fobjc-arc",
            "-fblocks",
            "-fobjc-runtime=" .. smallfw.objc_runtime(),
            "-I" .. projectdir,
            "-I" .. path.join(projectdir, "src"),
            "-fplugin=" .. plugin,
            "-fpass-plugin=" .. plugin,
            source,
            "-o",
            "-",
        })

        assert(ir:find("sf_object_set_generic_type_class", 1, true) ~= nil,
               "generic metadata runtime setter call missing from lowered IR")
        assert(ir:find("__smallfw_attach_generic_type_class", 1, true) == nil,
               "marker call should be removed by the LLVM pass")
        assert(ir:find("llvm.var.annotation", 1, true) == nil,
               "frontend annotation intrinsics should not remain in lowered IR")
    end)
