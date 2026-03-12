target("runtime-bench")
    set_group("benchmarks/runtime")
    smallfw.configure_runtime_binary_target({
        includedirs = {smallfw.project_path("src")},
    })
    add_files("main.m")
