target("value-object-demo")
    set_group("examples")
    smallfw.configure_runtime_binary_target({
        includedirs = {smallfw.project_path("src")},
    })
    add_files("main.m", {mflags = {"-fno-objc-arc"}})
