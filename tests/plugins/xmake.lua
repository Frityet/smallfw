local plugin_test_includedirs = {
    smallfw.project_path(),
    smallfw.project_path("src"),
}

target("plugin-generic-metadata-checks")
    set_group("tests/plugins")
    smallfw.configure_runtime_binary_target({
        includedirs = plugin_test_includedirs,
    })
    add_files("plugin_checks_stub.m")
    add_tests("plugin-generic-metadata-checks", {
        group = "plugins/generic-metadata",
        realtime_output = true,
    })
    on_test(function (target)
        import("lib.detect.find_program")

        local function flatten_flags(values)
            local flattened = {}
            for _, value in ipairs(values or {}) do
                if type(value) == "string" then
                    table.insert(flattened, value)
                elseif type(value) == "table" then
                    for _, entry in ipairs(value) do
                        if type(entry) == "string" then
                            table.insert(flattened, entry)
                        end
                    end
                end
            end
            return table.concat(flattened, "\n")
        end

        local mflags = flatten_flags(target:get("mflags"))
        local mxflags = flatten_flags(target:get("mxflags"))
        if not has_config("runtime-generic-metadata") then
            assert(mflags:find("-fplugin=", 1, true) == nil,
                   "generic metadata plugin flags should be absent when runtime-generic-metadata=n")
            assert(mxflags:find("-fplugin=", 1, true) == nil,
                   "Objective-C++ generic metadata plugin flags should be absent when runtime-generic-metadata=n")
            return true
        end

        assert(mflags:find("-fplugin=", 1, true) ~= nil,
               "clang frontend plugin flag missing when runtime-generic-metadata=y")
        assert(mxflags:find("-fplugin=", 1, true) ~= nil,
               "Objective-C++ clang frontend plugin flag missing when runtime-generic-metadata=y")
        assert(mflags:find("-fpass-plugin=", 1, true) ~= nil,
               "LLVM pass plugin flag missing when runtime-generic-metadata=y")
        assert(mxflags:find("-fpass-plugin=", 1, true) ~= nil,
               "Objective-C++ LLVM pass plugin flag missing when runtime-generic-metadata=y")

        local plugin_target = target:dep("smallfw-generics-plugin")
        assert(plugin_target ~= nil, "smallfw-generics-plugin dependency missing when runtime-generic-metadata=y")

        local clang = find_program("clang-21") or find_program("clang")
        assert(clang ~= nil, "clang is required for plugin IR verification")
        local opt = find_program("opt-21") or find_program("opt")
        assert(opt ~= nil, "opt is required for plugin IR verification")

        local projectdir = os.projectdir()
        local plugin = plugin_target:targetfile()
        assert(plugin ~= nil and plugin ~= "", "smallfw-generics-plugin target file is unavailable")
        if plugin:sub(1, 1) ~= "/" then
            plugin = projectdir .. "/" .. plugin
        end

        local objc_runtime = mflags:match("%-fobjc%-runtime=([^\n]+)") or "gnustep-2.3"
        local init_source = projectdir .. "/tests/plugins/generic_ir_init_check.m"
        local exception_source = projectdir .. "/tests/plugins/generic_ir_exception_check.m"

        local function compile_ir(source, opt_level)
            return os.iorunv(clang, {
                "-S",
                "-emit-llvm",
                "-O" .. tostring(opt_level),
                "-DSF_RUNTIME_GENERIC_METADATA=1",
                "-fobjc-arc",
                "-fblocks",
                "-fobjc-runtime=" .. objc_runtime,
                "-I" .. projectdir,
                "-I" .. projectdir .. "/src",
                "-fplugin=" .. plugin,
                "-fpass-plugin=" .. plugin,
                source,
                "-o",
                "-",
            })
        end

        local function verify_ir(source, opt_level)
            local ir = compile_ir(source, opt_level)
            local verify_path = os.tmpfile() .. ".ll"
            io.writefile(verify_path, ir)
            os.iorunv(opt, {
                "-passes=verify",
                verify_path,
                "-disable-output",
            })
            os.rm(verify_path)
            return ir
        end

        local function compile_object(source, opt_level)
            os.iorunv(clang, {
                "-c",
                "-O" .. tostring(opt_level),
                "-DSF_RUNTIME_GENERIC_METADATA=1",
                "-fobjc-arc",
                "-fblocks",
                "-fobjc-runtime=" .. objc_runtime,
                "-I" .. projectdir,
                "-I" .. projectdir .. "/src",
                "-fplugin=" .. plugin,
                "-fpass-plugin=" .. plugin,
                source,
                "-o",
                "/dev/null",
            })
        end

        local function extract_function(ir, name)
            local start = ir:find("@" .. name, 1, true)
            assert(start ~= nil, "missing function " .. name)

            local body = ir:sub(start):match("^.-%b{}")
            assert(body ~= nil, "failed to extract function body for " .. name)
            return body
        end

        local function assert_sequence(ir, needles, message)
            local cursor = 1
            for _, needle in ipairs(needles) do
                local next_pos = ir:find(needle, cursor, true)
                assert(next_pos ~= nil, message .. ": missing " .. needle)
                cursor = next_pos + 1
            end
        end

        local ir_o0 = verify_ir(init_source, 0)
        local function_o0 = extract_function(ir_o0, "sf_generic_ir_init_check")
        local _, setter_count_o0 = function_o0:gsub("sf_object_set_generic_type_class", "")

        assert(setter_count_o0 == 2,
               "expected two generic metadata setter calls in init check at -O0, got " .. tostring(setter_count_o0))
        assert_sequence(function_o0,
                        {
                            ".objc_selector_allocWithAllocator:",
                            "sf_object_set_generic_type_class",
                            ".objc_selector_init",
                            "sf_object_set_generic_type_class",
                        },
                        "generic metadata setters should bracket the init send at -O0")
        assert(ir_o0:find("__smallfw_attach_generic_type_class", 1, true) == nil,
               "marker call should be removed by the LLVM pass at -O0")
        assert(ir_o0:find("llvm.var.annotation", 1, true) == nil,
               "frontend annotation intrinsics should not remain in lowered IR at -O0")

        local ir_o2 = verify_ir(init_source, 2)
        local function_o2 = extract_function(ir_o2, "sf_generic_ir_init_check")
        local _, setter_count_o2 = function_o2:gsub("sf_object_set_generic_type_class", "")

        assert(setter_count_o2 == 2,
               "expected two generic metadata setter calls in init check at -O2, got " .. tostring(setter_count_o2))
        assert(ir_o2:find("__smallfw_attach_generic_type_class", 1, true) == nil,
               "marker call should be removed by the LLVM pass at -O2")
        assert(ir_o2:find("llvm.var.annotation", 1, true) == nil,
               "frontend annotation intrinsics should not remain in optimized lowered IR")
        compile_object(exception_source, 0)
        return true
    end)
