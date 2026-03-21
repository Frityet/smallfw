local runtime_test_suite_specs = {
    {
        name = "arc",
        provider = "sf_runtime_arc_cases",
        sourcefile = "runtime_test_arc.m",
        cases = {
            "arc_nil_operations",
            "arc_strong_store",
            "arc_strong_store_self",
            "arc_autorelease_pool",
            "arc_autorelease_no_pool",
            "arc_nested_autorelease_pools",
            "arc_marker_capacity_failure",
            "arc_autorelease_pool_fallback_token",
            "arc_autorelease_capacity_failure",
            "arc_factory_return",
            "arc_retain_release_balance",
            "arc_dead_object_noop_release",
            "arc_return_value_helpers",
            "arc_object_method_wrappers",
            "arc_object_nonheap_fallbacks",
            "arc_object_alloc_in_place",
            "arc_objc_alloc_init_success",
            "arc_large_autorelease_growth",
            "arc_large_marker_growth",
            "arc_pool_pop_marker_clamp",
            "arc_dispose_edge_paths",
            "arc_runtime_test_alloc_wrappers",
            "arc_objc_alloc_null",
            "arc_objc_alloc_missing_alloc",
            "arc_objc_alloc_init_missing_init",
            "allocator_custom_alloc_free",
            "allocator_default_alignment",
            "allocator_default_invalid_alignment",
        },
    },
    {
        name = "parent",
        provider = "sf_runtime_parent_cases",
        sourcefile = "runtime_test_parent.m",
        cases = function ()
            local cases = {
                "value_parent_layout_hidden_storage",
                "value_parent_alloc_embeds_in_parent",
                "value_parent_nontrivial_inline_rejected",
                "value_parent_duplicate_slots_reuse",
                "value_parent_child_expires_with_parent",
                "value_parent_standalone_heap_alloc",
                "value_parent_slot_exhaustion",
                "value_parent_oversized_subclass_rejected",
                "parent_group_inheritance",
                "parent_allocator_propagation",
                "parent_getter_lifecycle",
                "parent_child_outlives_parent",
                "parent_group_frees_on_last_release",
                "parent_nested_allocation_same_root",
                "parent_alloc_with_nil_parent",
                "parent_dead_parent_rejects_new_child",
            }
            if not smallfw.is_wasm() then
                table.insert(cases, "parent_concurrent_alloc_release")
            end
            return cases
        end,
    },
    {
        name = "dispatch",
        provider = "sf_runtime_dispatch_cases",
        sourcefile = "runtime_test_dispatch.m",
        cases = function ()
            local cases = {
                "dispatch_cache_warm_hits",
                "dispatch_super_lookup",
                "dispatch_selector_equality",
                "dispatch_selector_lookup_only_registration",
                "dispatch_method_lookup_canonical",
                "dispatch_c_msgsend_signatures",
                "dispatch_c_msgsend_unsupported_float",
                "dispatch_c_internal_helpers",
                "dispatch_struct_params",
                "dispatch_struct_returns",
                "dispatch_dtable_lookup",
                "dispatch_forwarding_targets",
            }
            if not smallfw.is_wasm() then
                table.insert(cases, "dispatch_concurrent_reads")
            end
            return cases
        end,
    },
    {
        name = "loader",
        provider = "sf_runtime_loader_cases",
        sourcefile = "runtime_test_loader.m",
        cases = function ()
            local cases = {
                "loader_lookup_nulls",
                "loader_lookup_missing",
                "loader_header_validation",
                "loader_header_size_modes",
                "loader_class_size_synthetic",
                "loader_abi_entrypoint_surface",
                "loader_hash_helpers",
                "loader_alloc_failure_paths",
                "loader_class_name_live_object",
            }
            if not smallfw.objc_runtime_is_objfw() then
                table.insert(cases, "loader_manual_registration")
            else
                table.insert(cases, "loader_objfw_exec_class")
            end
            if not smallfw.is_wasm() then
                table.insert(cases, 1, "no_libobjc_dependency")
            end
            if has_config("runtime-reflection") then
                for _, case_name in ipairs({
                    "reflection_class_lookup",
                    "reflection_inherited_method_lookup",
                    "reflection_method_lookup",
                    "reflection_ivar_lookup",
                    "reflection_inherited_ivar_lookup",
                    "reflection_null_paths",
                    "reflection_selector_lookup_only",
                    "reflection_failure_paths",
                    "reflection_full_map_exhaustion",
                }) do
                    table.insert(cases, case_name)
                end
            end
            if not smallfw.is_wasm() then
                table.insert(cases, "class_lookup_concurrent")
            end
            return cases
        end,
    },
    {
        name = "tagged",
        provider = "sf_runtime_tagged_cases",
        sourcefile = "runtime_test_tagged.m",
        cases = function ()
            if not has_config("runtime-tagged-pointers") then
                return {}
            end
            return {
                "tagged_arc_noop_semantics",
                "tagged_object_decode_paths",
                "tagged_dispatch_methods",
                "tagged_slot_registration_rules",
            }
        end,
    },
    {
        name = "exceptions",
        provider = "sf_runtime_exception_cases",
        sourcefile = "runtime_test_exceptions.m",
        cases = function ()
            if smallfw.is_wasm() then
                return {}
            end
            if not has_config("runtime-exceptions") then
                return {"exceptions_stubs_abort"}
            end
            return {
                "exceptions_begin_catch_passthrough",
                "exceptions_internal_helpers",
                "exceptions_backtrace_metadata",
                "exceptions_backtrace_metadata_alloc_failure",
                "exceptions_object_alloc_failure_throws",
                "exceptions_encoding_helpers",
                "exceptions_parse_lsda_helpers",
                "exceptions_personality_result_helper",
                "exceptions_catch_id",
                "exceptions_typed_exact",
                "exceptions_typed_subclass",
                "exceptions_finally_runs",
                "exceptions_rethrow",
                "exceptions_uncaught_abort",
                "exceptions_throw_alloc_failure_abort",
                "exceptions_direct_rethrow_abort",
                "exceptions_invalid_encoding_abort",
            }
        end,
    },
}

local runtime_test_case_cache = {}
local runtime_test_includedirs = {
    smallfw.project_path("src"),
    smallfw.project_path("tests/runtime"),
}

local function runtime_test_cases_for_suite(suite)
    local cached = runtime_test_case_cache[suite.name]
    if cached ~= nil then
        return cached
    end

    if type(suite.cases) == "function" then
        runtime_test_case_cache[suite.name] = suite.cases()
    else
        runtime_test_case_cache[suite.name] = suite.cases
    end
    return runtime_test_case_cache[suite.name]
end

local function runtime_test_sourcefiles()
    local files = {"runtime_tests.m", "runtime_test_support.m"}
    for _, suite in ipairs(runtime_test_suite_specs) do
        if #runtime_test_cases_for_suite(suite) > 0 then
            table.insert(files, suite.sourcefile)
        end
    end
    return files
end

local function runtime_test_suite_define_name(suite)
    return "SF_TEST_ENABLE_SUITE_" .. suite.name:upper()
end

target("runtime-tests")
    set_group("tests/runtime")
    smallfw.configure_runtime_binary_target({includedirs = runtime_test_includedirs})
    smallfw.add_wasm_node_test_script()
    for _, suite in ipairs(runtime_test_suite_specs) do
        if #runtime_test_cases_for_suite(suite) > 0 then
            add_defines(runtime_test_suite_define_name(suite))
        end
    end
    for _, sourcefile in ipairs(runtime_test_sourcefiles()) do
        add_files(sourcefile, {mflags = {"-fno-objc-arc"}})
    end

for _, suite in ipairs(runtime_test_suite_specs) do
    local suite_cases = runtime_test_cases_for_suite(suite)
    if #suite_cases > 0 then
        target("runtime-tests-" .. suite.name)
            set_group("tests/runtime/" .. suite.name)
            smallfw.configure_runtime_binary_target({includedirs = runtime_test_includedirs})
            smallfw.add_wasm_node_test_script()
            add_defines("SF_TEST_SUITE_LABEL=" .. suite.name, "SF_TEST_SUITE_PROVIDER=" .. suite.provider)
            add_files("runtime_tests.m", "runtime_test_support.m", suite.sourcefile, {mflags = {"-fno-objc-arc"}})
            if smallfw.is_wasm() and suite.name == "dispatch" then
                smallfw.add_wasm_browser_smoke_page({title = "runtime-tests-dispatch"})
            end
            for _, case_name in ipairs(suite_cases) do
                add_tests(case_name, {
                    group = "runtime/" .. suite.name,
                    realtime_output = true,
                    runargs = {"--case", case_name},
                })
            end
    end
end
