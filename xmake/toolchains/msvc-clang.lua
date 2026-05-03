local msvc_package_version = "14.43.17+13"

local function xmake_global_dir()
    local dir = os.getenv("XMAKE_GLOBALDIR")
    if dir ~= nil and dir ~= "" then
        return dir
    end
    local home = os.getenv("HOME") or os.getenv("USERPROFILE")
    if home == nil or home == "" then
        os.raise("smallfw-msvc-clang cannot locate the xmake package cache because HOME is unset")
    end
    return path.join(home, ".xmake")
end

local function is_msvc_sdk_dir(sdk)
    return sdk ~= nil and os.isdir(path.join(sdk, "VC", "Tools", "MSVC")) and os.isdir(path.join(sdk, "Windows Kits", "10"))
end

local function find_msvc_sdk()
    local candidates = os.dirs(path.join(xmake_global_dir(), "packages", "m", "msvc", msvc_package_version, "*"))
    table.sort(candidates)
    for index = #candidates, 1, -1 do
        local sdk = candidates[index]
        if is_msvc_sdk_dir(sdk) then
            return sdk
        end
    end
    return nil
end

local function target_triple(toolchain)
    if toolchain:is_arch("x64", "x86_64") then
        return "x86_64-pc-windows-msvc", "x64"
    end
    if toolchain:is_arch("x86", "i386", "i686") then
        return "i686-pc-windows-msvc", "x86"
    end
    if toolchain:is_arch("arm64", "aarch64") then
        return "aarch64-pc-windows-msvc", "arm64"
    end
    os.raise("smallfw-msvc-clang does not support architecture %s yet", toolchain:arch())
end

toolchain("smallfw-msvc-clang")
    set_kind("standalone")
    set_homepage("https://clang.llvm.org/")
    set_description("SmallFW clang driver targeting the MSVC Windows ABI through the xrepo MSVC SDK")
    set_runtimes("MT", "MTd", "MD", "MDd")

    set_toolset("cc", "clang")
    set_toolset("cxx", "clang++", "clang")
    set_toolset("mm", "clang")
    set_toolset("mxx", "clang++", "clang")
    set_toolset("as", "clang")
    set_toolset("ld", "clang++", "clang")
    set_toolset("sh", "clang++", "clang")
    set_toolset("ar", "llvm-ar")
    set_toolset("ranlib", "llvm-ranlib")
    set_toolset("strip", "llvm-strip")
    set_toolset("mrc", "llvm-rc")

    on_check(function (toolchain)
        import("lib.detect.find_tool")
        if find_tool("clang") == nil or find_tool("clang++") == nil then
            return false
        end
        return true
    end)

    on_load(function (toolchain)
        local sdk = find_msvc_sdk()
        if sdk == nil then
            os.raise("smallfw-msvc-clang needs the xrepo msvc " .. msvc_package_version .. " SDK package; install it with `xrepo install -y \"msvc " .. msvc_package_version .. "\"`")
        end

        local triple = target_triple(toolchain)

        local compile_flags = {
            "--target=" .. triple,
            "-Xmicrosoft-windows-sys-root",
            sdk,
        }
        local link_flags = {
            "--target=" .. triple,
            "-fuse-ld=lld",
            "-Xmicrosoft-windows-sys-root",
            sdk,
        }

        toolchain:add("cxflags", table.unpack(compile_flags))
        toolchain:add("mxflags", table.unpack(compile_flags))
        toolchain:add("asflags", "--target=" .. triple)
        toolchain:add("ldflags", table.unpack(link_flags))
        toolchain:add("shflags", table.unpack(link_flags))
        toolchain:config_set("smallfw_msvc_sdk", sdk)
    end)
