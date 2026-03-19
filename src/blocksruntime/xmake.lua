-- Vendored from https://github.com/mackyle/blocksruntime @ 9cc93ae2b58676c23fd02cf0c686fa15b7a3ff81

target("smallfw-blocksruntime")
    set_group("runtime/third_party")
    set_kind("static")
    set_languages("gnu11")
    set_warnings("none")
    add_includedirs(".", "..")
    add_headerfiles("*.h", {prefixdir = "blocksruntime"})
    add_files("data.c", "runtime.c")
    if is_plat("linux") then
        add_defines("_POSIX_C_SOURCE=200809L", {force = true})
    end
    add_cflags("-Wno-everything", {force = true})
