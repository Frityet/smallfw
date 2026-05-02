target("stdlib-tests")
    set_group("tests/stdlib")
    set_kind("binary")
    set_default(false)
    if is_mode("release") then
        set_optimize("fastest")
    end
    add_options(smallfw.runtime_build_options)
    add_deps("smallfw-stdlib")
    add_includedirs(smallfw.project_path("StandardLibrary", "src"))
    add_includedirs(smallfw.project_path("Runtime", "SFRuntime", "src"))
    add_includedirs(smallfw.project_path("Runtime", "SFBlocksRuntime", "src"))
    add_rules("smallfw.runtime.common")
    add_rules("smallfw.generic_metadata")
    add_rules("smallfw.runtime.binary")
    add_files("stdlib-tests.m")
    add_tests("stdlib-core", {
        group = "stdlib",
        realtime_output = true,
    })

target("stdlib-module-smoke")
    set_group("tests/stdlib/modules")
    set_kind("binary")
    set_default(false)
    add_options(smallfw.runtime_build_options)
    add_deps("smallfw-stdlib")
    add_rules("smallfw.runtime.common")
    add_rules("smallfw.runtime.binary")
    add_files("module-smoke.m", {mflags = {"-fno-objc-arc"}})
    add_tests("stdlib_module_smoke", {group = "stdlib", realtime_output = true})

if has_config("runtime-generic-metadata") then
    target("stdlib-tests-generic-class")
        set_group("tests/stdlib/generic-metadata")
        set_kind("binary")
        set_default(false)
        if is_mode("release") then
            set_optimize("fastest")
        end
        add_options(smallfw.runtime_build_options)
        add_deps("smallfw-stdlib")
        add_includedirs(smallfw.project_path("StandardLibrary", "src"))
        add_includedirs(smallfw.project_path("Runtime", "SFRuntime", "src"))
        add_includedirs(smallfw.project_path("Runtime", "SFBlocksRuntime", "src"))
        add_rules("smallfw.runtime.common")
        add_rules("smallfw.generic_metadata")
        add_rules("smallfw.runtime.binary")
        add_files("stdlib-generic-metadata-tests.m")
        add_tests("stdlib-generic-class", {
            group = "stdlib/generic-metadata",
            realtime_output = true,
        })

    target("stdlib-generic-metadata-bad-placement")
        set_group("tests/stdlib/generic-metadata")
        set_kind("object")
        set_default(false)
        add_options(smallfw.runtime_build_options)
        add_deps("smallfw-stdlib")
        add_includedirs(smallfw.project_path("StandardLibrary", "src"))
        add_includedirs(smallfw.project_path("Runtime", "SFRuntime", "src"))
        add_includedirs(smallfw.project_path("Runtime", "SFBlocksRuntime", "src"))
        add_rules("smallfw.runtime.common")
        add_rules("smallfw.generic_metadata")
        add_files("generic-metadata-bad-placement.m")
        add_tests("generic-metadata-bad-placement", {
            group = "stdlib/generic-metadata",
            build_should_fail = true,
        })

    target("stdlib-generic-metadata-non-generic-interface")
        set_group("tests/stdlib/generic-metadata")
        set_kind("object")
        set_default(false)
        add_options(smallfw.runtime_build_options)
        add_deps("smallfw-stdlib")
        add_includedirs(smallfw.project_path("StandardLibrary", "src"))
        add_includedirs(smallfw.project_path("Runtime", "SFRuntime", "src"))
        add_includedirs(smallfw.project_path("Runtime", "SFBlocksRuntime", "src"))
        add_rules("smallfw.runtime.common")
        add_rules("smallfw.generic_metadata")
        add_files("generic-metadata-non-generic-interface.m")
        add_tests("generic-metadata-non-generic-interface", {
            group = "stdlib/generic-metadata",
            build_should_fail = true,
        })
end
