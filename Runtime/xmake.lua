local runtime_src = "src"
local blocks_src = path.join(runtime_src, "Blocks")
local dispatch_src = path.join(runtime_src, "dispatch")
local exceptions_src = path.join(runtime_src, "exceptions")
local smallfw_src = path.join(runtime_src, "SmallFW")

local function add_runtime_sources()
    add_files(
        path.join(runtime_src, "allocator.c"),
        path.join(runtime_src, "arc.c"),
        path.join(runtime_src, "encoding.m"),
        path.join(runtime_src, "helpers.c"),
        path.join(runtime_src, "loader-common.c"),
        path.join(runtime_src, "loader-gnustep.c"),
        path.join(runtime_src, "object-header.c"),
        path.join(dispatch_src, "dispatch.c"),
        path.join(exceptions_src, "exceptions.c")
    )
    if is_mode("test") then
        add_files(path.join(runtime_src, "testhooks.c"))
    end
    add_files(path.join(smallfw_src, "AllocationFailedException.m"), {mflags = {"-fno-objc-arc"}})
    add_files(path.join(smallfw_src, "InvalidArgumentException.m"), {mflags = {"-fno-objc-arc"}})
    add_files(path.join(smallfw_src, "Object.m"), {mflags = {"-fno-objc-arc"}})

    if is_plat("mingw") and has_config("runtime-exceptions") then
        add_files(path.join(exceptions_src, "exceptions-mingw.mm"), {mxflags = {"-fno-objc-arc"}})
    end

    if smallfw.runtime_dispatch_backend() == "asm" and is_arch("x86_64") and not is_plat("mingw") then
        add_files(path.join(dispatch_src, "dispatch-x86-64.asm"), {sourcekind = "as", asflags = {"-x", "assembler-with-cpp"}})
    else
        add_files(path.join(dispatch_src, "dispatch-c.c"))
        if not is_plat("mingw") then
            add_links("ffi", {public = true})
        end
    end
end

target("smallfw-blocksruntime")
    set_group("runtime/blocks")
    set_kind("static")
    set_languages("gnu23")
    set_warnings("none")
    add_options(smallfw.runtime_build_options)
    add_rules("smallfw.runtime.common")
    add_rules("utils.install.cmake_importfiles")
    add_rules("utils.install.pkgconfig_importfiles")
    add_includedirs(runtime_src, {public = true})
    add_headerfiles(path.join(blocks_src, "*.h"), {prefixdir = "Blocks"})
    add_headerfiles(path.join(runtime_src, "SFRuntime.modulemap"), {prefixdir = "."})
    add_files(path.join(blocks_src, "data.m"), path.join(blocks_src, "runtime.m"), {mflags = {"-fno-objc-arc"}})
    if is_plat("linux") then
        add_defines("_POSIX_C_SOURCE=200809L", {force = true})
    end
    add_cflags("-Wno-everything", {force = true})
    add_mflags("-Wno-everything", {force = true})

target("smallfw-runtime-objects")
    set_default(false)
    set_group("runtime/internal")
    set_kind("object")
    add_options(smallfw.runtime_build_options)
    add_deps("smallfw-blocksruntime", {public = true})
    add_includedirs(runtime_src, {public = true})
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
    add_includedirs(runtime_src, {public = true})
    add_rules("smallfw.runtime.common")
    add_rules("smallfw.generic_metadata")
    add_rules("utils.install.cmake_importfiles")
    add_rules("utils.install.pkgconfig_importfiles")

    add_headerfiles(path.join(smallfw_src, "*.h"), {prefixdir = "SmallFW"})
    add_headerfiles(path.join(blocks_src, "*.h"), {prefixdir = "Blocks"})
    add_headerfiles(path.join(runtime_src, "abi.h"),
                    path.join(runtime_src, "c2x-compat.h"),
                    path.join(runtime_src, "encoding.h"),
                    path.join(runtime_src, "locking.h"),
                    path.join(runtime_src, "objc-runtime-exports.h"),
                    path.join(runtime_src, "sf-allocator.h"),
                    {prefixdir = "."})
    add_headerfiles(path.join(runtime_src, "SFRuntime.modulemap"), {prefixdir = "."})

    add_runtime_sources()

includes("tests")
includes("tests/fuzz/dispatch")
includes("tests/fuzz/loader")
includes("tests/fuzz/exceptions")
