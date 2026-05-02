local runtime_src = "src/runtime"
local smallfw_src = "src/smallfw"

local function add_runtime_sources()
    add_files(
        path.join(runtime_src, "allocator.c"),
        path.join(runtime_src, "arc.c"),
        path.join(runtime_src, "dispatch.c"),
        path.join(runtime_src, "exceptions.c"),
        path.join(runtime_src, "helpers.c"),
        path.join(runtime_src, "loader/common.c"),
        path.join(runtime_src, "loader/gnustep.c"),
        path.join(runtime_src, "object-header.c")
    )
    if is_mode("test") then
        add_files(path.join(runtime_src, "testhooks.c"))
    end
    add_files(path.join(smallfw_src, "AllocationFailedException.m"), {mflags = {"-fno-objc-arc"}})
    add_files(path.join(smallfw_src, "InvalidArgumentException.m"), {mflags = {"-fno-objc-arc"}})
    add_files(path.join(smallfw_src, "Object.m"), {mflags = {"-fno-objc-arc"}})

    if is_plat("mingw") and has_config("runtime-exceptions") then
        add_files(path.join(runtime_src, "exceptions-mingw.mm"), {mxflags = {"-fno-objc-arc"}})
    end

    if smallfw.runtime_dispatch_backend() == "asm" and is_arch("x86_64") and not is_plat("mingw") then
        add_files(path.join(runtime_src, "dispatch-x86-64.asm"), {sourcekind = "as", asflags = {"-x", "assembler-with-cpp"}})
    else
        add_files(path.join(runtime_src, "dispatch-c.c"))
        if not is_plat("mingw") then
            add_links("ffi", {public = true})
        end
    end
end

target("smallfw-runtime-objects")
    set_default(false)
    set_group("runtime/internal")
    set_kind("object")
    add_options(smallfw.runtime_build_options)
    add_deps("smallfw-blocksruntime", {public = true})
    add_includedirs("src", {public = true})
    add_rules("smallfw.runtime.common")
    add_rules("smallfw.generic_metadata")
    add_runtime_sources()

target("smallfw-runtime")
    set_group("runtime")
    set_kind("static")
    if is_mode("release") then
        set_optimize("fastest")
    end
    add_options(smallfw.runtime_build_options)
    add_deps("smallfw-blocksruntime", {public = true})
    add_includedirs("src", {public = true})
    add_rules("smallfw.runtime.common")
    add_rules("smallfw.generic_metadata")
    add_rules("utils.install.cmake_importfiles")
    add_rules("utils.install.pkgconfig_importfiles")

    add_headerfiles(path.join(smallfw_src, "*.h"), {prefixdir = "smallfw"})
    add_headerfiles(path.join(runtime_src, "abi.h"),
                    path.join(runtime_src, "c2x-compat.h"),
                    path.join(runtime_src, "locking.h"),
                    path.join(runtime_src, "sf-allocator.h"),
                    {prefixdir = "runtime"})
    add_headerfiles(path.join(runtime_src, "objc/runtime-exports.h"), {prefixdir = "runtime/objc"})
    add_headerfiles(path.join("src", "SFRuntime.modulemap"), {prefixdir = "."})

    add_runtime_sources()

includes("tests")
includes("tests/fuzz/dispatch")
includes("tests/fuzz/loader")
includes("tests/fuzz/exceptions")
