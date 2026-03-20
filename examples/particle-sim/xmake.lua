target("particle-sim")
    set_group("examples")
    set_languages("gnu23", "gnuxx26")
    smallfw.configure_runtime_binary_target({
        includedirs = {smallfw.project_path("src")},
    })
    add_deps("smallfw-stdlib")
    add_files("**.m")
