target("stdlib-tests")
    set_group("tests/stdlib")
    smallfw.configure_runtime_binary_target({
        deps = {"smallfw-stdlib"},
        includedirs = {
            smallfw.project_path(),
            smallfw.project_path("src"),
        },
    })
    add_files("stdlib_tests.m")
    add_tests("stdlib-literals", {
        group = "stdlib",
        realtime_output = true,
    })
