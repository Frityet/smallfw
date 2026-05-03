target("runtime-bench")
    set_group("benchmarking/runtime")
    set_kind("binary")
    set_default(false)
    if is_mode("release") then
        set_optimize("fastest")
    end

    add_options(smallfw.runtime_build_options)
    add_deps(smallfw.runtime_binary_dependency())
    add_includedirs(smallfw.project_path("Runtime", "src"))
    add_rules("smallfw.runtime.common")
    add_rules("smallfw.generic_metadata")
    add_rules("smallfw.runtime.binary")
    add_files("src/runtime-bench.m")
