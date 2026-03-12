if not is_plat("mingw") then
    target("runtime-fuzz-dispatch")
        set_group("tests/fuzz/dispatch")
        smallfw.configure_runtime_binary_target({
            includedirs = {smallfw.project_path("src")},
            fuzz_sanitizer = true,
        })
        add_files("fuzz_dispatch_parser.c")
        if smallfw.runtime_dispatch_backend() == "asm" and is_arch("x86_64") then
            -- The parser helpers live in dispatch_c.c even when the runtime fast path is assembly.
            add_files(smallfw.project_path("src/runtime/dispatch_c.c"))
            add_links("ffi")
        end
end
