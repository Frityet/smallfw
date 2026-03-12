target("smallfw-runtime")
    set_group("runtime")
    smallfw.configure_runtime_library_target()

    add_files(
        "allocator.c",
        "arc.c",
        "dispatch.c",
        "exceptions.c",
        "helpers.c",
        "loader.c",
        "object_header.c",
        "testhooks.c"
    )
    if is_plat("mingw") and has_config("runtime-exceptions") then
        add_files("exceptions_mingw.mm", {mxflags = {"-fno-objc-arc"}})
    end

    if smallfw.runtime_dispatch_backend() == "asm" then
        if is_arch("x86_64") then
            if is_plat("mingw") then
                add_files("dispatch_c.c")
            else
                add_files("dispatch_x86_64.asm", {sourcekind = "as", asflags = {"-x", "assembler-with-cpp"}})
            end
        else
            add_files("dispatch_c.c")
            if not is_plat("mingw") then
                add_links("ffi", {public = true})
            end
        end
    else
        add_files("dispatch_c.c")
        if not is_plat("mingw") then
            add_links("ffi", {public = true})
        end
    end

    add_files("../smallfw/**.m", {mflags = {"-fno-objc-arc"}})
