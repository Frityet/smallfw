local stdlib_src = "src/SFStdLib"

target("smallfw-stdlib")
    set_group("stdlib")
    set_kind("static")
    if is_mode("release") then
        set_optimize("fastest")
    end
    add_options(smallfw.runtime_build_options)
    add_deps(smallfw.runtime_binary_dependency(), {public = true})
    add_includedirs("src", smallfw.project_path("Runtime", "src"), {public = true})
    add_rules("smallfw.runtime.common")
    add_rules("smallfw.generic_metadata")
    add_rules("utils.install.cmake_importfiles")
    add_rules("utils.install.pkgconfig_importfiles")
    add_headerfiles(path.join(stdlib_src, "*.h"), {prefixdir = "SFStdLib"})
    add_headerfiles(path.join(stdlib_src, "Collections", "*.h"), {prefixdir = "SFStdLib/Collections"})
    add_headerfiles(path.join(stdlib_src, "Exceptions", "*.h"), {prefixdir = "SFStdLib/Exceptions"})
    add_headerfiles(path.join(stdlib_src, "Reflection", "*.h"), {prefixdir = "SFStdLib/Reflection"})
    add_headerfiles("src/SFStdLib.modulemap", {prefixdir = "."})
    add_files(path.join(stdlib_src, "Collections", "Array.m"), {mflags = smallfw.no_objc_arc_file_flags()})
    add_files(path.join(stdlib_src, "Collections", "List.m"), {mflags = smallfw.no_objc_arc_file_flags()})
    add_files(path.join(stdlib_src, "Collections", "Map.m"), {mflags = smallfw.no_objc_arc_file_flags()})
    add_files(path.join(stdlib_src, "Exceptions", "Exception.m"), {mflags = smallfw.no_objc_arc_file_flags()})
    add_files(path.join(stdlib_src, "Number.m"), {mflags = smallfw.no_objc_arc_file_flags()})
    add_files(path.join(stdlib_src, "Reflection", "Reflection.m"), {mflags = smallfw.no_objc_arc_file_flags()})
    add_files(path.join(stdlib_src, "String.m"), {mflags = smallfw.no_objc_arc_file_flags()})

includes("tests")
