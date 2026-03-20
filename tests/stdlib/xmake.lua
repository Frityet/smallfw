local stdlib_test_includedirs = {
    smallfw.project_path(),
    smallfw.project_path("src"),
}

target("stdlib-tests")
    set_group("tests/stdlib")
    smallfw.configure_runtime_binary_target({
        deps = {"smallfw-stdlib"},
        includedirs = stdlib_test_includedirs,
    })
    add_files("stdlib_tests.m")
    add_tests("stdlib-core", {
        group = "stdlib",
        realtime_output = true,
    })

if has_config("runtime-generic-metadata") then
    local function configure_stdlib_object_target()
        set_kind("object")
        set_default(false)
        add_options(smallfw.runtime_build_options)
        add_deps("smallfw-stdlib")
        for _, includedir in ipairs(stdlib_test_includedirs) do
            add_includedirs(includedir)
        end
        smallfw.add_common_runtime_flags()
        smallfw.add_generic_plugin_settings()
        smallfw.add_runtime_mode_defines()
        smallfw.add_analysis_symbol_settings()
        smallfw.add_runtime_sanitizer_settings()
    end

    target("stdlib-tests-generic-class")
        set_group("tests/stdlib/generic-metadata")
        smallfw.configure_runtime_binary_target({
            deps = {"smallfw-stdlib"},
            includedirs = stdlib_test_includedirs,
        })
        add_files("stdlib_generic_metadata_tests.m")
        add_tests("stdlib-generic-class", {
            group = "stdlib/generic-metadata",
            realtime_output = true,
        })

    target("stdlib-generic-metadata-bad-placement")
        set_group("tests/stdlib/generic-metadata")
        configure_stdlib_object_target()
        add_files("generic_metadata_bad_placement.m")
        add_tests("generic-metadata-bad-placement", {
            group = "stdlib/generic-metadata",
            build_should_fail = true,
        })

    target("stdlib-generic-metadata-non-generic-interface")
        set_group("tests/stdlib/generic-metadata")
        configure_stdlib_object_target()
        add_files("generic_metadata_non_generic_interface.m")
        add_tests("generic-metadata-non-generic-interface", {
            group = "stdlib/generic-metadata",
            build_should_fail = true,
        })
end
