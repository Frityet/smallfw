if not is_plat("mingw") then
    target("runtime-fuzz-loader")
        set_group("tests/fuzz/loader")
        smallfw.configure_runtime_binary_target({
            includedirs = {smallfw.project_path("src")},
            fuzz_sanitizer = true,
        })
        add_files("fuzz_loader_layout.c")
end
