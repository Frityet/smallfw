if not is_plat("mingw", "windows") and not is_plat("wasm") then
    target("runtime-fuzz-dispatch")
        set_group("tests/fuzz/dispatch")
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
        add_rules("smallfw.runtime.fuzz_sanitizer")

        add_files("fuzz-dispatch-parser.c")
        if smallfw.runtime_dispatch_backend() ~= "c" then
            -- The parser helpers live in dispatch-c.c even when the runtime fast path is assembly.
            add_files(smallfw.project_path("Runtime", "src", "dispatch", "dispatch-c.c"), {defines = {"SF_RUNTIME_DISPATCH_PARSER_ONLY=1"}})
        end
end
