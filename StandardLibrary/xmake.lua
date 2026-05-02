local stdlib_src = "src/StandardLibrary"

target("smallfw-stdlib")
    set_group("stdlib")
    set_kind("static")
    if is_mode("release") then
        set_optimize("fastest")
    end
    add_options(smallfw.runtime_build_options)
    add_deps(smallfw.runtime_binary_dependency(), {public = true})
    add_deps("smallfw-blocksruntime", {public = true})
    add_includedirs("src", smallfw.project_path("Runtime", "SFRuntime", "src"), smallfw.project_path("Runtime", "SFBlocksRuntime", "src"), {public = true})
    add_rules("smallfw.runtime.common")
    add_rules("smallfw.generic_metadata")
    add_rules("utils.install.cmake_importfiles")
    add_rules("utils.install.pkgconfig_importfiles")
    add_headerfiles(path.join(stdlib_src, "*.h"), {prefixdir = "StandardLibrary"})
    add_headerfiles("src/SFStandardLibrary.modulemap", {prefixdir = "."})
    add_files(path.join(stdlib_src, "Array.m"), {mflags = {"-fno-objc-arc"}})
    add_files(path.join(stdlib_src, "Block.m"), {mflags = {"-fno-objc-arc"}})
    add_files(path.join(stdlib_src, "Exception.m"), {mflags = {"-fno-objc-arc"}})
    add_files(path.join(stdlib_src, "List.m"), {mflags = {"-fno-objc-arc"}})
    add_files(path.join(stdlib_src, "Map.m"), {mflags = {"-fno-objc-arc"}})
    add_files(path.join(stdlib_src, "Number.m"), {mflags = {"-fno-objc-arc"}})
    add_files(path.join(stdlib_src, "String.m"), {mflags = {"-fno-objc-arc"}})

includes("tests")
