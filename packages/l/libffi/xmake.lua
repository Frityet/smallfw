package("libffi")
    set_homepage("https://sourceware.org/libffi/")
    set_description("Portable Foreign Function Interface library.")
    set_license("MIT")

    set_urls("https://github.com/libffi/libffi/releases/download/v$(version)/libffi-$(version).tar.gz")
    add_versions("3.5.2", "f3a3082a23b37c293a4fcd1053147b371f2ff91fa7ea1b2a52e335676bac82dc")

    on_install("wasm", function (package)
        import("core.base.option")
        import("package.tools.autoconf")

        local host = package:arch() .. "-unknown-emscripten"
        local configs = {
            "--disable-shared",
            "--enable-static",
            "--disable-docs",
        }
        configs.host = host

        local buildenvs = autoconf.buildenvs(package)
        autoconf.configure(package, configs, {envs = buildenvs})

        local jobs = "-j" .. tostring(option.get("jobs") or os.default_njob())
        autoconf.make(package, {"-C", host, jobs}, {envs = buildenvs})
        autoconf.make(package, {"-C", host, "install"}, {envs = buildenvs})
    end)

    on_test(function (package)
        assert(os.isfile(package:installdir("include", "ffi.h")))
        assert(os.isfile(package:installdir("lib", "libffi.a")))
    end)
