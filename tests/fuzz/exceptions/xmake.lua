if not is_plat("mingw") then
    target("runtime-fuzz-exceptions")
        set_group("tests/fuzz/exceptions")
        smallfw.configure_runtime_binary_target({
            includedirs = {smallfw.project_path("src")},
            fuzz_sanitizer = true,
        })
        add_files("fuzz_exceptions_lsda.c")
end
