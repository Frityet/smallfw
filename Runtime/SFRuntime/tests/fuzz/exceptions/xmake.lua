if not is_plat("mingw") and not is_plat("wasm") and has_config("runtime-exceptions") then
    target("runtime-fuzz-exceptions")
        set_group("tests/fuzz/exceptions")
        set_kind("binary")
        set_default(false)
        if is_mode("release") then
            set_optimize("fastest")
        end

        add_options(smallfw.runtime_build_options)
        add_deps(smallfw.runtime_binary_dependency())
        add_includedirs(smallfw.project_path("Runtime", "SFRuntime", "src"))
        add_includedirs(smallfw.project_path("Runtime", "SFBlocksRuntime", "src"))
        add_rules("smallfw.runtime.common")
        add_rules("smallfw.generic_metadata")
        add_rules("smallfw.runtime.binary")
        add_rules("smallfw.runtime.fuzz_sanitizer")

        add_files("fuzz-exceptions-lsda.c")
end
