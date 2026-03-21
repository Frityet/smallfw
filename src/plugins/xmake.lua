local function trim(value)
    return value:gsub("^%s+", ""):gsub("%s+$", "")
end

local function find_llvm_config()
    if os.isfile("/usr/bin/llvm-config-21") then
        return "/usr/bin/llvm-config-21"
    end
    if os.isfile("/usr/bin/llvm-config") then
        return "/usr/bin/llvm-config"
    end
    return "llvm-config-21"
end

if not is_plat("wasm") then
    target("smallfw-generics-plugin")
        set_group("plugins")
        set_kind("shared")
        set_default(false)
        set_languages("gnuxx17")
        set_policy("build.fence", true)
        add_files("generics_plugin.cpp")
        on_load(function (target)
            local llvm_config = find_llvm_config()
            assert(llvm_config ~= nil, "llvm-config 21 is required to build smallfw-generics-plugin")

            local includedir = trim(os.iorunv(llvm_config, {"--includedir"}))
            local libdir = trim(os.iorunv(llvm_config, {"--libdir"}))

            target:add("sysincludedirs", includedir)
            target:add("linkdirs", libdir)
            target:add("rpathdirs", libdir)
            target:add("links", "clang-cpp", "LLVM-21")
            target:add("cxflags",
                       "-fno-exceptions",
                       "-funwind-tables",
                       "-D_GNU_SOURCE",
                       "-D__STDC_CONSTANT_MACROS",
                       "-D__STDC_FORMAT_MACROS",
                       "-D__STDC_LIMIT_MACROS",
                       {force = true})
        end)
end
