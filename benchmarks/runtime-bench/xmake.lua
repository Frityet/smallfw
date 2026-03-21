target("runtime-bench")
    set_group("benchmarks/runtime")
    smallfw.configure_runtime_binary_target({
        includedirs = {smallfw.project_path("src")},
    })
    if smallfw.is_wasm() then
        smallfw.add_wasm_node_test_script()
        add_tests("runtime-bench-list", {
            group = "benchmarks/runtime",
            realtime_output = true,
            runargs = {"--list"},
        })
    end
    add_files("main.m")
