target("framework-tests")
    set_group("tests/framework")
    smallfw.configure_runtime_binary_target({
        deps = {"smallfw-framework"},
        includedirs = {
            smallfw.project_path(),
            smallfw.project_path("src"),
        },
    })
    add_files("framework_tests.m")
    add_tests("framework-literals", {
        group = "framework",
        realtime_output = true,
    })
