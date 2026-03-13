import("core.base.json")
import("core.base.option")
import("smallfw.task_helpers")

local CASE_ORDER = {
    "dispatch_monomorphic_hot",
    "dispatch_polymorphic_hot",
    "arc_retain_release_heap",
    "arc_retain_release_round_robin",
    "arc_store_strong_cycle",
    "alloc_init_release_plain",
    "parent_group_cycle",
}

local CASE_TITLES = {
    dispatch_monomorphic_hot = "dispatch_monomorphic_hot",
    dispatch_polymorphic_hot = "dispatch_polymorphic_hot",
    arc_retain_release_heap = "arc_retain_release_heap",
    arc_retain_release_round_robin = "arc_retain_release_round_robin",
    arc_store_strong_cycle = "arc_store_strong_cycle",
    alloc_init_release_plain = "alloc_init_release_plain",
    parent_group_cycle = "parent_group_cycle",
}

local MODE_ORDER = {"release", "debug"}

local ABI_ENTRIES = {
    {
        id = "gnustep-2.3",
        slug = "gnustep",
        label = "GNUstep ABI",
    },
    {
        id = "objfw-1.5",
        slug = "objfw",
        label = "ObjFW ABI",
    },
}

local CURATED_VARIANTS = {
    {
        id = "release-default",
        category = "Modes",
        note = "Release build with runtime defaults. This is the matrix baseline.",
    },
    {
        id = "release-native-tuning",
        category = "Whole-program",
        options = {["runtime-native-tuning"] = "y"},
        note = "Enables -march=native and -mtune=native.",
    },
    {
        id = "release-thinlto",
        category = "Whole-program",
        options = {["runtime-thinlto"] = "y"},
        note = "Enables ThinLTO.",
    },
    {
        id = "release-full-lto",
        category = "Whole-program",
        options = {["runtime-full-lto"] = "y"},
        note = "Enables full LTO.",
    },
    {
        id = "release-pgo-gen",
        category = "Instrumentation",
        pgo = "gen",
        note = "Instrumentation-only PGO generation build.",
    },
    {
        id = "release-pgo-use",
        category = "Whole-program",
        pgo = "use",
        note = "Profile-guided optimization on the default release stack.",
    },
    {
        id = "release-pgo-use-bolt",
        category = "Whole-program",
        pgo = "use",
        bolt = "on",
        note = "Default release stack with PGO and BOLT.",
    },
    {
        id = "release-full-lto-pgo",
        category = "Whole-program",
        pgo = "use",
        options = {
            ["runtime-full-lto"] = "y",
        },
        note = "Measured best whole-program stack without native tuning.",
    },
    {
        id = "release-full-lto-native-pgo-bolt",
        category = "Whole-program",
        pgo = "use",
        bolt = "on",
        options = {
            ["runtime-full-lto"] = "y",
            ["runtime-native-tuning"] = "y",
        },
        note = "Measured fastest release stack on Linux x86_64: full LTO, native tuning, PGO, and BOLT.",
    },
    {
        id = "release-dispatch-c",
        category = "Dispatch / behavior",
        options = {["dispatch-backend"] = "c"},
        note = "Uses the C message send path instead of the assembly fast path.",
    },
    {
        id = "release-forwarding",
        category = "Dispatch / behavior",
        options = {["runtime-forwarding"] = "y"},
        note = "Enables forwarding and the cold miss path.",
    },
    {
        id = "release-validation",
        category = "Dispatch / behavior",
        options = {["runtime-validation"] = "y"},
        note = "Adds defensive object validation checks.",
    },
    {
        id = "release-tagged-pointers",
        category = "Dispatch / behavior",
        options = {["runtime-tagged-pointers"] = "y"},
        note = "Enables tagged pointer support.",
    },
    {
        id = "release-exceptions-off",
        category = "Dispatch / behavior",
        options = {["runtime-exceptions"] = "n"},
        note = "Disables Objective-C exceptions support.",
    },
    {
        id = "release-reflection-off",
        category = "Dispatch / behavior",
        options = {["runtime-reflection"] = "n"},
        note = "Disables reflection support.",
    },
    {
        id = "release-compact-headers",
        category = "Layout / ABI",
        options = {["runtime-compact-headers"] = "y"},
        note = "Uses the compact runtime object header layout.",
    },
    {
        id = "release-inline-value-storage",
        category = "Layout / ABI",
        options = {
            ["runtime-compact-headers"] = "y",
            ["runtime-inline-value-storage"] = "y",
        },
        note = "Enables compact inline ValueObject prefixes and the compact-header prerequisite.",
    },
    {
        id = "release-inline-group-state",
        category = "Layout / ABI",
        options = {
            ["runtime-compact-headers"] = "y",
            ["runtime-inline-group-state"] = "y",
        },
        note = "Stores parent/group bookkeeping inline and enables the compact-header prerequisite.",
    },
    {
        id = "release-analysis-symbols",
        category = "Instrumentation",
        options = {["analysis-symbols"] = "y"},
        note = "Keeps debug symbols, disables strip, and emits relocations.",
    },
}

local FULL_VARIANTS = {
    {
        id = "debug-default",
        mode = "debug",
        category = "Modes",
        note = "Debug build with runtime defaults. This is the debug baseline.",
    },
    {
        id = "debug-dispatch-c",
        mode = "debug",
        category = "Dispatch / behavior",
        options = {["dispatch-backend"] = "c"},
        note = "Uses the C message send path instead of the assembly fast path.",
    },
    {
        id = "debug-exceptions-off",
        mode = "debug",
        category = "Dispatch / behavior",
        options = {["runtime-exceptions"] = "n"},
        note = "Disables Objective-C exceptions support.",
    },
    {
        id = "debug-reflection-off",
        mode = "debug",
        category = "Dispatch / behavior",
        options = {["runtime-reflection"] = "n"},
        note = "Disables reflection support.",
    },
    {
        id = "debug-forwarding",
        mode = "debug",
        category = "Dispatch / behavior",
        options = {["runtime-forwarding"] = "y"},
        note = "Enables forwarding and the cold miss path.",
    },
    {
        id = "debug-validation",
        mode = "debug",
        category = "Dispatch / behavior",
        options = {["runtime-validation"] = "y"},
        note = "Adds defensive object validation checks.",
    },
    {
        id = "debug-tagged-pointers",
        mode = "debug",
        category = "Dispatch / behavior",
        options = {["runtime-tagged-pointers"] = "y"},
        note = "Enables tagged pointer support.",
    },
    {
        id = "debug-compact-headers",
        mode = "debug",
        category = "Layout / ABI",
        options = {["runtime-compact-headers"] = "y"},
        note = "Uses the compact runtime object header layout.",
    },
    {
        id = "debug-inline-value-storage",
        mode = "debug",
        category = "Layout / ABI",
        options = {
            ["runtime-compact-headers"] = "y",
            ["runtime-inline-value-storage"] = "y",
        },
        note = "Enables compact inline ValueObject prefixes and the compact-header prerequisite.",
    },
    {
        id = "debug-inline-group-state",
        mode = "debug",
        category = "Layout / ABI",
        options = {
            ["runtime-compact-headers"] = "y",
            ["runtime-inline-group-state"] = "y",
        },
        note = "Stores parent/group bookkeeping inline and enables the compact-header prerequisite.",
    },
    {
        id = "debug-sanitize",
        mode = "debug",
        category = "Instrumentation",
        options = {["runtime-sanitize"] = "y"},
        note = "Enables ASan and UBSan for analysis builds.",
    },
    {
        id = "release-default",
        mode = "release",
        category = "Modes",
        note = "Release build with runtime defaults. This is the release baseline.",
    },
    {
        id = "release-dispatch-c",
        mode = "release",
        category = "Dispatch / behavior",
        options = {["dispatch-backend"] = "c"},
        note = "Uses the C message send path instead of the assembly fast path.",
    },
    {
        id = "release-exceptions-off",
        mode = "release",
        category = "Dispatch / behavior",
        options = {["runtime-exceptions"] = "n"},
        note = "Disables Objective-C exceptions support.",
    },
    {
        id = "release-reflection-off",
        mode = "release",
        category = "Dispatch / behavior",
        options = {["runtime-reflection"] = "n"},
        note = "Disables reflection support.",
    },
    {
        id = "release-forwarding",
        mode = "release",
        category = "Dispatch / behavior",
        options = {["runtime-forwarding"] = "y"},
        note = "Enables forwarding and the cold miss path.",
    },
    {
        id = "release-validation",
        mode = "release",
        category = "Dispatch / behavior",
        options = {["runtime-validation"] = "y"},
        note = "Adds defensive object validation checks.",
    },
    {
        id = "release-tagged-pointers",
        mode = "release",
        category = "Dispatch / behavior",
        options = {["runtime-tagged-pointers"] = "y"},
        note = "Enables tagged pointer support.",
    },
    {
        id = "release-compact-headers",
        mode = "release",
        category = "Layout / ABI",
        options = {["runtime-compact-headers"] = "y"},
        note = "Uses the compact runtime object header layout.",
    },
    {
        id = "release-inline-value-storage",
        mode = "release",
        category = "Layout / ABI",
        options = {
            ["runtime-compact-headers"] = "y",
            ["runtime-inline-value-storage"] = "y",
        },
        note = "Enables compact inline ValueObject prefixes and the compact-header prerequisite.",
    },
    {
        id = "release-inline-group-state",
        mode = "release",
        category = "Layout / ABI",
        options = {
            ["runtime-compact-headers"] = "y",
            ["runtime-inline-group-state"] = "y",
        },
        note = "Stores parent/group bookkeeping inline and enables the compact-header prerequisite.",
    },
    {
        id = "release-analysis-symbols",
        mode = "release",
        category = "Instrumentation",
        options = {["analysis-symbols"] = "y"},
        note = "Keeps debug symbols, disables strip, and emits relocations.",
    },
    {
        id = "release-native-tuning",
        mode = "release",
        category = "Whole-program",
        options = {["runtime-native-tuning"] = "y"},
        note = "Enables -march=native and -mtune=native.",
    },
    {
        id = "release-thinlto",
        mode = "release",
        category = "Whole-program",
        options = {["runtime-thinlto"] = "y"},
        note = "Enables ThinLTO.",
    },
    {
        id = "release-full-lto",
        mode = "release",
        category = "Whole-program",
        options = {["runtime-full-lto"] = "y"},
        note = "Enables full LTO.",
    },
}

local DISPLAY_OPTION_ORDER = {
    "analysis-symbols",
    "objc-runtime",
    "dispatch-backend",
    "runtime-exceptions",
    "runtime-reflection",
    "runtime-forwarding",
    "runtime-validation",
    "runtime-tagged-pointers",
    "runtime-sanitize",
    "runtime-native-tuning",
    "runtime-thinlto",
    "runtime-full-lto",
    "runtime-compact-headers",
    "runtime-inline-value-storage",
    "runtime-inline-group-state",
}

local function _string_option(name, default_value)
    local value = option.get(name)
    if value == nil or value == "" then
        return default_value
    end
    return value
end

local function _positive_integer_option(name, default_value)
    local raw = option.get(name)
    if raw == nil or raw == "" then
        return default_value
    end

    local value = tonumber(raw)
    assert(value ~= nil and value >= 1 and math.floor(value) == value,
        string.format("option --%s must be a positive integer", name))
    return value
end

local function _nonnegative_integer_option(name, default_value)
    local raw = option.get(name)
    if raw == nil or raw == "" then
        return default_value
    end

    local value = tonumber(raw)
    assert(value ~= nil and value >= 0 and math.floor(value) == value,
        string.format("option --%s must be a non-negative integer", name))
    return value
end

local function _sorted_keys(tbl, order)
    local keys = {}
    local seen = {}
    for _, key in ipairs(order or {}) do
        if tbl[key] ~= nil then
            table.insert(keys, key)
            seen[key] = true
        end
    end
    for key in pairs(tbl or {}) do
        if not seen[key] then
            table.insert(keys, key)
        end
    end
    table.sort(keys)
    return keys
end

local function _ordered_option_keys(tbl)
    local keys = {}
    local seen = {}
    for _, key in ipairs(DISPLAY_OPTION_ORDER) do
        if tbl[key] ~= nil then
            table.insert(keys, key)
            seen[key] = true
        end
    end
    for key in pairs(tbl or {}) do
        if not seen[key] then
            table.insert(keys, key)
        end
    end
    return keys
end

local function _table_clone(src)
    local dst = {}
    for key, value in pairs(src or {}) do
        dst[key] = value
    end
    return dst
end

local function _selected_abis()
    local selected = _string_option("objc-runtimes", "both")
    if selected == "both" then
        return ABI_ENTRIES
    end

    for _, abi in ipairs(ABI_ENTRIES) do
        if abi.id == selected then
            return {abi}
        end
    end

    raise("option --objc-runtimes must be one of: both, gnustep-2.3, objfw-1.5")
end

local function _matrix_kind()
    local kind = _string_option("matrix", "full")
    if kind ~= "curated" and kind ~= "full" then
        raise("option --matrix must be one of: curated, full")
    end
    return kind
end

local function _selected_variant_templates(kind)
    if kind == "full" then
        return FULL_VARIANTS
    end
    return CURATED_VARIANTS
end

local function _find_abi_entry(abi_entries, abi_id)
    for _, abi in ipairs(abi_entries or {}) do
        if abi.id == abi_id then
            return abi
        end
    end
    return nil
end

local function _expanded_variants(abi_entries, variant_templates)
    local expanded = {}
    for _, variant in ipairs(variant_templates or {}) do
        for _, abi in ipairs(abi_entries or {}) do
            local concrete = _table_clone(variant)
            concrete.base_id = variant.id
            concrete.id = variant.id .. "-" .. abi.slug
            concrete.objc_runtime = abi.id
            concrete.abi_slug = abi.slug
            concrete.abi_label = abi.label
            concrete.mode = variant.mode or "release"
            table.insert(expanded, concrete)
        end
    end
    return expanded
end

local function _selected_abis_value(abi_entries)
    if #(abi_entries or {}) == #ABI_ENTRIES then
        return "both"
    end
    local abi = abi_entries and abi_entries[1] or nil
    return abi and abi.id or "both"
end

local function _effective_options(variant)
    local options = {
        ["analysis-symbols"] = "n",
        ["objc-runtime"] = variant.objc_runtime or "gnustep-2.3",
    }
    for key, value in pairs(variant.options or {}) do
        options[key] = value
    end
    return options
end

local function _visible_changed_options(variant)
    local options = _effective_options(variant)
    local keys = _ordered_option_keys(options)
    local entries = {}
    for _, key in ipairs(keys) do
        local value = options[key]
        local include = true
        if key == "analysis-symbols" and value == "n" then
            include = false
        end
        if include then
            table.insert(entries, string.format("`%s=%s`", key, value))
        end
    end
    if #entries == 0 then
        return "-"
    end
    return table.concat(entries, ", ")
end

local function _format_speedup(value)
    return string.format("%.2fx", value)
end

local function _format_ns(value)
    return string.format("%.3f ns", value)
end

local function _strip_ansi(value)
    local text = value or ""
    text = text:gsub("\27%[[%d;?]*[%a]", "")
    text = text:gsub("\27%][^\7]*\7", "")
    return text
end

local function _single_line(value)
    local text = _strip_ansi(value)
    for line in text:gmatch("[^\r\n]+") do
        local trimmed = task_helpers.trim(line)
        if trimmed ~= "" then
            return trimmed
        end
    end
    return nil
end

local function _variant_failure_message(rootdir, variant)
    local run_dir = path.join(rootdir, "runs", variant.id)
    local files = {
        path.join(run_dir, "sample-01.csv"),
        path.join(run_dir, "build.log"),
        path.join(run_dir, "configure.log"),
        path.join(run_dir, "pgo", "build.log"),
        path.join(run_dir, "pgo", "configure.log"),
        path.join(run_dir, "bolt", "llvm-bolt.log"),
        path.join(run_dir, "bolt", "perf2bolt.log"),
        path.join(run_dir, "bolt", "perf.record.log"),
    }
    for _, filename in ipairs(files) do
        if os.isfile(filename) then
            local content = io.readfile(filename) or ""
            local last = nil
            local last_error = nil
            local last_specific_error = nil
            for line in _strip_ansi(content):gmatch("[^\r\n]+") do
                local trimmed = task_helpers.trim(line)
                if trimmed ~= "" then
                    last = trimmed
                    if trimmed:find("error:", 1, true) then
                        last_error = trimmed
                        if not trimmed:find("linker command failed with exit code", 1, true) then
                            last_specific_error = trimmed
                        end
                    end
                end
            end
            if last_specific_error ~= nil then
                return last_specific_error
            end
            if last_error ~= nil then
                return last_error
            end
            if last ~= nil then
                return last
            end
        end
    end
    return "unknown error"
end

local function _failure_by_id(failures)
    local by_id = {}
    for _, failure in ipairs(failures or {}) do
        by_id[failure.id] = failure
    end
    return by_id
end

local function _geomean(values)
    if #values == 0 then
        return 0.0
    end
    local sum = 0.0
    for _, value in ipairs(values) do
        sum = sum + math.log(value)
    end
    return math.exp(sum / #values)
end

local function _first_value(tbl)
    for _, value in pairs(tbl or {}) do
        return value
    end
    return nil
end

local function _baseline_base_id(mode)
    return tostring(mode or "release") .. "-default"
end

local function _baseline_key(objc_runtime, mode)
    return tostring(objc_runtime or "") .. "::" .. tostring(mode or "release")
end

local function _ordered_bucket(ordered_by_speed, objc_runtime, mode)
    local by_runtime = ordered_by_speed[objc_runtime]
    if by_runtime == nil then
        by_runtime = {}
        ordered_by_speed[objc_runtime] = by_runtime
    end
    local bucket = by_runtime[mode]
    if bucket == nil then
        bucket = {}
        by_runtime[mode] = bucket
    end
    return bucket
end

local function _bench_command_args(rootdir, samples, warmups, variant)
    local args = {
        "run-runtime-bench",
        "--case=all",
        "--samples=" .. tostring(samples),
        "--warmups=" .. tostring(warmups),
        "--outdir=" .. path.join(rootdir, "runs"),
        "--tag=" .. variant.id,
        "--mode=" .. tostring(variant.mode or "release"),
        "--pgo=" .. tostring(variant.pgo or "off"),
        "--bolt=" .. tostring(variant.bolt or "off"),
    }

    for _, key in ipairs(_ordered_option_keys(_effective_options(variant))) do
        table.insert(args, "--" .. key .. "=" .. tostring(_effective_options(variant)[key]))
    end
    return args
end

local function _variant_envs(variant)
    local options = _effective_options(variant)
    if options["runtime-sanitize"] ~= "y" then
        return nil
    end

    return {
        ASAN_OPTIONS = "detect_leaks=0:abort_on_error=1",
        UBSAN_OPTIONS = "halt_on_error=1:print_stacktrace=1",
    }
end

local function _run_variant(rootdir, samples, warmups, variant)
    local run_dir = path.join(rootdir, "runs", variant.id)
    os.tryrm(run_dir)
    task_helpers.run_xmake(_bench_command_args(rootdir, samples, warmups, variant), {
        envs = _variant_envs(variant),
    })

    local summary = json.decode(io.readfile(path.join(run_dir, "summary.json")))
    local metadata = json.decode(io.readfile(path.join(run_dir, "metadata.json")))
    local cases = {}
    for _, case_result in ipairs(summary.cases or {}) do
        cases[case_result.name] = case_result
    end

    for _, case_name in ipairs(CASE_ORDER) do
        assert(cases[case_name] ~= nil, string.format("variant %s did not report benchmark case %s", variant.id, case_name))
    end

    return {
        id = variant.id,
        base_id = variant.base_id or variant.id,
        category = variant.category,
        note = variant.note,
        mode = variant.mode or "release",
        pgo = variant.pgo or "off",
        bolt = variant.bolt or "off",
        objc_runtime = variant.objc_runtime or "gnustep-2.3",
        abi_label = variant.abi_label or (variant.objc_runtime or "gnustep-2.3"),
        abi_slug = variant.abi_slug or (variant.objc_runtime or "gnustep-2.3"),
        options = _effective_options(variant),
        changed_options = _visible_changed_options(variant),
        run_dir = path.absolute(run_dir),
        summary = summary,
        metadata = metadata,
        cases = cases,
    }
end

local function _derive_relative_metrics(results_by_id, variants, abi_entries)
    local baselines_by_key = {}
    local fastest_by_case = {}
    local ordered_by_speed = {}

    for _, variant in ipairs(variants or {}) do
        local result = results_by_id[variant.id]
        if result ~= nil and result.base_id == _baseline_base_id(result.mode) then
            baselines_by_key[_baseline_key(result.objc_runtime, result.mode)] = result
        end
    end

    for _, abi in ipairs(abi_entries or {}) do
        local seen_modes = {}
        for _, variant in ipairs(variants or {}) do
            if variant.objc_runtime == abi.id then
                seen_modes[variant.mode or "release"] = true
            end
        end
        for mode in pairs(seen_modes) do
            assert(baselines_by_key[_baseline_key(abi.id, mode)] ~= nil,
                string.format("the %s %s baseline failed, so the matrix cannot be rendered", abi.id, _baseline_base_id(mode)))
        end
    end

    for _, variant in ipairs(variants or {}) do
        local result = results_by_id[variant.id]
        if result ~= nil then
            local baseline = baselines_by_key[_baseline_key(result.objc_runtime, result.mode)]
            local speedups = {}
            local best = nil
            local worst = nil

            for _, case_name in ipairs(CASE_ORDER) do
                local baseline_case = baseline.cases[case_name]
                local current_case = result.cases[case_name]
                local speedup = baseline_case.mean_ns_per / current_case.mean_ns_per
                current_case.speedup_vs_baseline = speedup
                table.insert(speedups, speedup)

                if best == nil or speedup > best.speedup then
                    best = {case = case_name, speedup = speedup}
                end
                if worst == nil or speedup < worst.speedup then
                    worst = {case = case_name, speedup = speedup}
                end

                local fastest = fastest_by_case[case_name]
                if fastest == nil or current_case.mean_ns_per < fastest.mean_ns_per then
                    fastest_by_case[case_name] = {
                        variant = result.base_id,
                        run_id = result.id,
                        abi = result.objc_runtime,
                        abi_label = result.abi_label,
                        mode = result.mode,
                        mean_ns_per = current_case.mean_ns_per,
                        speedup = speedup,
                    }
                end
            end

            result.geomean_speedup = _geomean(speedups)
            result.best_case = best
            result.worst_case = worst
            table.insert(_ordered_bucket(ordered_by_speed, result.objc_runtime, result.mode), result)
        end
    end

    for _, abi in ipairs(abi_entries or {}) do
        for _, mode in ipairs(MODE_ORDER) do
            local bucket = ordered_by_speed[abi.id] and ordered_by_speed[abi.id][mode] or nil
            if bucket ~= nil then
                table.sort(bucket, function (a, b)
                    if a.geomean_speedup == b.geomean_speedup then
                        return a.id < b.id
                    end
                    return a.geomean_speedup > b.geomean_speedup
                end)
            end
        end
    end

    return baselines_by_key, fastest_by_case, ordered_by_speed
end

local function _derive_abi_comparisons(results_by_id, abi_entries, variant_templates)
    local comparisons = {}
    local gnustep = _find_abi_entry(abi_entries, "gnustep-2.3")
    local objfw = _find_abi_entry(abi_entries, "objfw-1.5")
    if gnustep == nil or objfw == nil then
        return comparisons
    end

    for _, variant in ipairs(variant_templates or {}) do
        local gnustep_result = results_by_id[variant.id .. "-" .. gnustep.slug]
        local objfw_result = results_by_id[variant.id .. "-" .. objfw.slug]
        if gnustep_result ~= nil and objfw_result ~= nil then
            local objfw_speedups = {}
            local best = nil
            local worst = nil

            for _, case_name in ipairs(CASE_ORDER) do
                local gnustep_case = gnustep_result.cases[case_name]
                local objfw_case = objfw_result.cases[case_name]
                local speedup = gnustep_case.mean_ns_per / objfw_case.mean_ns_per
                table.insert(objfw_speedups, speedup)

                if best == nil or speedup > best.speedup then
                    best = {case = case_name, speedup = speedup}
                end
                if worst == nil or speedup < worst.speedup then
                    worst = {case = case_name, speedup = speedup}
                end
            end

            table.insert(comparisons, {
                base_id = variant.id,
                note = variant.note,
                mode = variant.mode or "release",
                gnustep = gnustep_result,
                objfw = objfw_result,
                objfw_geomean_speedup = _geomean(objfw_speedups),
                best_case = best,
                worst_case = worst,
            })
        end
    end

    table.sort(comparisons, function (a, b)
        if a.objfw_geomean_speedup == b.objfw_geomean_speedup then
            return a.base_id < b.base_id
        end
        return a.objfw_geomean_speedup > b.objfw_geomean_speedup
    end)

    return comparisons
end

local function _markdown_header(lines, level, text)
    table.insert(lines, string.rep("#", level) .. " " .. text)
    table.insert(lines, "")
end

local function _append_table(lines, headers, rows)
    table.insert(lines, "| " .. table.concat(headers, " | ") .. " |")
    local separators = {}
    for _ = 1, #headers do
        table.insert(separators, "---")
    end
    table.insert(lines, "| " .. table.concat(separators, " | ") .. " |")
    for _, row in ipairs(rows) do
        table.insert(lines, "| " .. table.concat(row, " | ") .. " |")
    end
    table.insert(lines, "")
end

local function _mode_label(mode)
    if mode == "debug" then
        return "Debug"
    end
    return "Release"
end

local function _matrix_title(matrix_kind)
    if matrix_kind == "curated" then
        return "Runtime Performance Matrix (Curated)"
    end
    return "Runtime Performance Matrix"
end

local function _results_for_bucket(variants, results_by_id, objc_runtime, mode)
    local rows = {}
    for _, variant in ipairs(variants or {}) do
        if variant.objc_runtime == objc_runtime and (variant.mode or "release") == mode then
            local result = results_by_id[variant.id]
            if result ~= nil then
                table.insert(rows, result)
            end
        end
    end
    return rows
end

local function _result_present(results_by_id, id)
    return results_by_id[id] ~= nil
end

local function _render_markdown(matrix_kind, doc_path, outroot, samples, warmups, generated_at_utc, host_metadata,
                                variants, abi_entries, results_by_id, baselines_by_key, ordered_by_speed,
                                fastest_by_case, abi_comparisons, failures)
    local lines = {}
    local failures_by_id = _failure_by_id(failures)
    local selected_abis = _selected_abis_value(abi_entries)
    local host_info = (host_metadata and host_metadata.host) or {}
    local successful_variants = 0
    local benchmark_labels = {}
    local has_sanitize_rows = _result_present(results_by_id, "debug-sanitize-gnustep") or
        _result_present(results_by_id, "debug-sanitize-objfw")
    for _, case_name in ipairs(CASE_ORDER) do
        table.insert(benchmark_labels, string.format("`%s`", CASE_TITLES[case_name]))
    end
    for _ in pairs(results_by_id or {}) do
        successful_variants = successful_variants + 1
    end

    _markdown_header(lines, 1, _matrix_title(matrix_kind))
    table.insert(lines,
        "This document is generated from measured `xmake run-runtime-bench` runs on the current host.")
    if matrix_kind == "full" then
        table.insert(lines,
            "The full matrix covers every Linux `x86_64` runtime mode/flag row currently exercised by the repo matrix across the selected Objective-C ABIs.")
    else
        table.insert(lines,
            "The curated matrix focuses on the tuned release-oriented variants, including PGO and BOLT rows.")
    end
    table.insert(lines,
        "Relative speedups are computed against the matching mode baseline inside the same ABI: `debug-default` for debug rows and `release-default` for release rows.")
    table.insert(lines, "")
    table.insert(lines, string.format("Generated at: `%s`", generated_at_utc))
    table.insert(lines, string.format("Regenerate with: `xmake run-runtime-performance-matrix --matrix=%s --samples=%d --warmups=%d --objc-runtimes=%s --outdir=%s --doc=%s`",
        matrix_kind, samples, warmups, selected_abis, outroot, doc_path))
    table.insert(lines, "")

    _markdown_header(lines, 2, "Environment")
    table.insert(lines, string.format("- Host: `%s`", host_info.host or os.host()))
    table.insert(lines, string.format("- Architecture: `%s`", host_info.arch or os.arch()))
    local abi_labels = {}
    for _, abi in ipairs(abi_entries or {}) do
        table.insert(abi_labels, string.format("`%s`", abi.id))
    end
    table.insert(lines, string.format("- Objective-C runtimes benchmarked: %s", table.concat(abi_labels, ", ")))
    if host_info.uname ~= nil then
        table.insert(lines, string.format("- `uname -srvm`: `%s`", host_info.uname))
    end
    if host_info.clang ~= nil then
        table.insert(lines, string.format("- `clang --version`: `%s`", _single_line(host_info.clang) or "unknown"))
    end
    if host_info.xmake ~= nil then
        table.insert(lines, string.format("- `xmake --version`: `%s`", _single_line(host_info.xmake) or "unknown"))
    end
    table.insert(lines, string.format("- Samples per variant: `%d`", samples))
    table.insert(lines, string.format("- Warmups per variant: `%d`", warmups))
    table.insert(lines, string.format("- Benchmark artifact root: `%s`", path.absolute(outroot)))
    table.insert(lines, "")

    _markdown_header(lines, 2, "Methodology")
    table.insert(lines, "- Summary tables report sample means in nanoseconds.")
    table.insert(lines, "- Geometric means are computed from per-benchmark speedups against the matching ABI+mode baseline.")
    table.insert(lines, "- Detailed `median`, `min`, `max`, and `stdev` values are preserved in `matrix.json` and each variant `summary.json`.")
    table.insert(lines, "- `runtime-bench` pins execution to CPU 0 via `taskset` when available.")
    if has_sanitize_rows then
        table.insert(lines,
            "- Sanitized rows are run with `ASAN_OPTIONS=detect_leaks=0:abort_on_error=1` and `UBSAN_OPTIONS=halt_on_error=1:print_stacktrace=1`.")
    end
    table.insert(lines, "")

    _markdown_header(lines, 2, "Coverage")
    table.insert(lines, string.format("- Matrix kind: `%s`", matrix_kind))
    table.insert(lines, string.format("- Variants attempted: `%d`", #(variants or {})))
    table.insert(lines, string.format("- Variants completed: `%d`", successful_variants))
    table.insert(lines, string.format("- Variants failed: `%d`", #(failures or {})))
    table.insert(lines, string.format("- Benchmarks: %s", table.concat(benchmark_labels, ", ")))
    table.insert(lines, "")

    _markdown_header(lines, 2, "Variant Definitions")
    local variant_rows = {}
    for _, variant in ipairs(variants or {}) do
        local result = results_by_id[variant.id]
        local failure = failures_by_id[variant.id]
        local options = result and result.changed_options or _visible_changed_options(variant)
        table.insert(variant_rows, {
            "`" .. (variant.base_id or variant.id) .. "`",
            "`" .. (variant.objc_runtime or "gnustep-2.3") .. "`",
            variant.category,
            "`" .. tostring(variant.mode or "release") .. "`",
            "`" .. tostring(variant.pgo or "off") .. "`",
            "`" .. tostring(variant.bolt or "off") .. "`",
            options,
            result and "ok" or "failed",
            failure and ("`" .. _single_line(failure.error) .. "`") or "-",
            variant.note,
        })
    end
    _append_table(lines, {"Variant", "ABI", "Category", "Mode", "PGO", "BOLT", "Changed Options", "Status", "Failure", "Notes"}, variant_rows)

    _markdown_header(lines, 2, "Leaderboard")
    for _, abi in ipairs(abi_entries or {}) do
        for _, mode in ipairs(MODE_ORDER) do
            local leaderboard = ordered_by_speed[abi.id] and ordered_by_speed[abi.id][mode] or nil
            if leaderboard ~= nil and #leaderboard > 0 then
                _markdown_header(lines, 3, string.format("%s %s", abi.label, _mode_label(mode)))
                local leaderboard_rows = {}
                for rank, result in ipairs(leaderboard) do
                    table.insert(leaderboard_rows, {
                        tostring(rank),
                        "`" .. result.base_id .. "`",
                        result.category,
                        _format_speedup(result.geomean_speedup),
                        string.format("`%s` (%s)", result.best_case.case, _format_speedup(result.best_case.speedup)),
                        string.format("`%s` (%s)", result.worst_case.case, _format_speedup(result.worst_case.speedup)),
                        result.note,
                    })
                end
                _append_table(lines, {
                    "Rank",
                    "Variant",
                    "Category",
                    string.format("Geo Mean vs ABI `%s`", _baseline_base_id(mode)),
                    "Best Case",
                    "Worst Case",
                    "Notes",
                }, leaderboard_rows)
            end
        end
    end

    if #abi_comparisons > 0 then
        _markdown_header(lines, 2, "ObjFW vs GNUstep")
        for _, mode in ipairs(MODE_ORDER) do
            local abi_rows = {}
            for _, comparison in ipairs(abi_comparisons) do
                if comparison.mode == mode then
                    local winner = "tie"
                    if comparison.objfw_geomean_speedup > 1.01 then
                        winner = "ObjFW ABI"
                    elseif comparison.objfw_geomean_speedup < 0.99 then
                        winner = "GNUstep ABI"
                    end
                    table.insert(abi_rows, {
                        "`" .. comparison.base_id .. "`",
                        _format_speedup(comparison.objfw_geomean_speedup),
                        winner,
                        string.format("`%s` (%s)", comparison.best_case.case, _format_speedup(comparison.best_case.speedup)),
                        string.format("`%s` (%s)", comparison.worst_case.case, _format_speedup(comparison.worst_case.speedup)),
                        comparison.note,
                    })
                end
            end
            if #abi_rows > 0 then
                _markdown_header(lines, 3, _mode_label(mode))
                _append_table(lines, {"Variant", "ObjFW vs GNUstep", "Winner", "Best ObjFW Case", "Worst ObjFW Case", "Notes"}, abi_rows)
            end
        end
    end

    _markdown_header(lines, 2, "Fastest Variant Per Benchmark")
    local fastest_rows = {}
    for _, case_name in ipairs(CASE_ORDER) do
        local fastest = fastest_by_case[case_name]
        table.insert(fastest_rows, {
            "`" .. CASE_TITLES[case_name] .. "`",
            "`" .. fastest.variant .. "`",
            "`" .. tostring(fastest.mode or "release") .. "`",
            fastest.abi_label,
            _format_ns(fastest.mean_ns_per),
            _format_speedup(fastest.speedup),
        })
    end
    _append_table(lines, {"Benchmark", "Fastest Variant", "Mode", "ABI", "Mean", "Speedup vs matching baseline"}, fastest_rows)

    local gnustep = _find_abi_entry(abi_entries, "gnustep-2.3")
    local objfw = _find_abi_entry(abi_entries, "objfw-1.5")
    if gnustep ~= nil or objfw ~= nil then
        _markdown_header(lines, 2, "ASM vs C Backend")
        local asm_rows = {}
        for _, mode in ipairs(MODE_ORDER) do
            for _, abi in ipairs(abi_entries or {}) do
                local asm_result = results_by_id[_baseline_base_id(mode) .. "-" .. abi.slug]
                local c_result = results_by_id[mode .. "-dispatch-c-" .. abi.slug]
                if asm_result ~= nil and c_result ~= nil then
                    for _, case_name in ipairs(CASE_ORDER) do
                        local asm_case = asm_result.cases[case_name]
                        local c_case = c_result.cases[case_name]
                        table.insert(asm_rows, {
                            abi.label,
                            "`" .. mode .. "`",
                            "`" .. CASE_TITLES[case_name] .. "`",
                            _format_ns(asm_case.mean_ns_per),
                            _format_ns(c_case.mean_ns_per),
                            _format_speedup(c_case.mean_ns_per / asm_case.mean_ns_per),
                        })
                    end
                end
            end
        end
        if #asm_rows > 0 then
            _append_table(lines, {"ABI", "Mode", "Benchmark", "ASM Mean", "C Mean", "ASM Advantage"}, asm_rows)
        end
    end

    _markdown_header(lines, 2, "Detailed Matrix")
    for _, abi in ipairs(abi_entries or {}) do
        for _, mode in ipairs(MODE_ORDER) do
            local rows = {}
            local bucket_results = _results_for_bucket(variants, results_by_id, abi.id, mode)
            for _, result in ipairs(bucket_results) do
                table.insert(rows, {
                    "`" .. result.base_id .. "`",
                    result.category,
                    _format_speedup(result.geomean_speedup),
                    _format_ns(result.cases.dispatch_monomorphic_hot.mean_ns_per),
                    _format_ns(result.cases.dispatch_polymorphic_hot.mean_ns_per),
                    _format_ns(result.cases.arc_retain_release_heap.mean_ns_per),
                    _format_ns(result.cases.arc_retain_release_round_robin.mean_ns_per),
                    _format_ns(result.cases.arc_store_strong_cycle.mean_ns_per),
                    _format_ns(result.cases.alloc_init_release_plain.mean_ns_per),
                    _format_ns(result.cases.parent_group_cycle.mean_ns_per),
                    result.note,
                })
            end
            if #rows > 0 then
                _markdown_header(lines, 3, string.format("%s %s", abi.label, _mode_label(mode)))
                _append_table(lines, {
                    "Variant",
                    "Category",
                    string.format("Geo Mean vs `%s`", _baseline_base_id(mode)),
                    "dispatch_monomorphic_hot",
                    "dispatch_polymorphic_hot",
                    "arc_retain_release_heap",
                    "arc_retain_release_round_robin",
                    "arc_store_strong_cycle",
                    "alloc_init_release_plain",
                    "parent_group_cycle",
                    "Notes",
                }, rows)
            end
        end
    end

    if #failures > 0 then
        _markdown_header(lines, 2, "Failed Variants")
        for _, failure in ipairs(failures) do
            table.insert(lines, string.format("- `%s`: `%s`", failure.id, failure.error:gsub("\n", " ")))
        end
        table.insert(lines, "")
    end

    _markdown_header(lines, 2, "Baseline Reference")
    for _, abi in ipairs(abi_entries or {}) do
        for _, mode in ipairs(MODE_ORDER) do
            local baseline = baselines_by_key[_baseline_key(abi.id, mode)]
            if baseline ~= nil then
                table.insert(lines, string.format("- `%s %s`: `%s`", abi.id, _baseline_base_id(mode), baseline.run_dir))
            end
        end
    end
    table.insert(lines, string.format("- Matrix JSON: `%s`", path.absolute(path.join(outroot, "matrix.json"))))
    table.insert(lines, "")

    return table.concat(lines, "\n")
end

function main()
    assert(os.host() == "linux", "run-runtime-performance-matrix is only supported on Linux hosts.")

    local matrix_kind = _matrix_kind()
    local samples = _positive_integer_option("samples", matrix_kind == "full" and 5 or 1)
    local warmups = _nonnegative_integer_option("warmups", matrix_kind == "full" and 1 or 0)
    local outroot = _string_option("outdir", matrix_kind == "full"
        and path.join("build", "runtime-analysis", "performance-matrix-full")
        or path.join("build", "runtime-analysis", "performance-matrix"))
    local doc_path = _string_option("doc", matrix_kind == "full"
        and path.join("docs", "PERFORMANCE.md")
        or path.join("docs", "PERFORMANCE_CURATED.md"))
    local abi_entries = _selected_abis()
    local variant_templates = _selected_variant_templates(matrix_kind)
    local variants = _expanded_variants(abi_entries, variant_templates)

    os.mkdir(outroot)
    os.mkdir(path.join(outroot, "runs"))
    os.mkdir(path.directory(doc_path))

    local results_by_id = {}
    local failures = {}

    for index, variant in ipairs(variants) do
        print(string.format("[%d/%d] %s (%s)", index, #variants, variant.base_id, variant.abi_label))
        local ok, result, errs = try {
            function ()
                return true, _run_variant(outroot, samples, warmups, variant)
            end,
            catch {
                function (errors)
                    return false, nil, errors
                end
            }
        }
        if ok then
            results_by_id[variant.id] = result
        else
            table.insert(failures, {
                id = variant.id,
                base_id = variant.base_id,
                objc_runtime = variant.objc_runtime,
                error = _single_line(tostring(errs or _variant_failure_message(outroot, variant))) or "unknown error",
            })
        end
    end

    local baselines_by_runtime, fastest_by_case, ordered_by_speed =
        _derive_relative_metrics(results_by_id, variants, abi_entries)
    local abi_comparisons = _derive_abi_comparisons(results_by_id, abi_entries, variant_templates)
    local generated_at_utc = os.date("!%Y-%m-%dT%H:%M:%SZ")
    local first_baseline = _first_value(baselines_by_runtime)
    local host_metadata = (first_baseline and first_baseline.metadata) or {}
    local matrix_json = {
        matrix_kind = matrix_kind,
        generated_at_utc = generated_at_utc,
        outroot = path.absolute(outroot),
        samples = samples,
        warmups = warmups,
        selected_abis = _selected_abis_value(abi_entries),
        abis = {},
        abi_comparisons = {},
        variants = {},
        failures = failures,
    }
    for _, abi in ipairs(abi_entries) do
        table.insert(matrix_json.abis, {
            id = abi.id,
            slug = abi.slug,
            label = abi.label,
        })
    end
    for _, variant in ipairs(variants) do
        local result = results_by_id[variant.id]
        if result ~= nil then
            local cases = {}
            for _, case_name in ipairs(CASE_ORDER) do
                local case_result = result.cases[case_name]
                table.insert(cases, {
                    name = case_name,
                    mean_ns_per = case_result.mean_ns_per,
                    median_ns_per = case_result.median_ns_per,
                    min_ns_per = case_result.min_ns_per,
                    max_ns_per = case_result.max_ns_per,
                    stdev_ns_per = case_result.stdev_ns_per,
                    speedup_vs_baseline = case_result.speedup_vs_baseline,
                })
            end
            table.insert(matrix_json.variants, {
                id = result.id,
                base_id = result.base_id,
                objc_runtime = result.objc_runtime,
                abi_label = result.abi_label,
                category = result.category,
                note = result.note,
                mode = result.mode,
                pgo = result.pgo,
                bolt = result.bolt,
                changed_options = result.changed_options,
                baseline_run_id = baselines_by_runtime[_baseline_key(result.objc_runtime, result.mode)]
                    and baselines_by_runtime[_baseline_key(result.objc_runtime, result.mode)].id or nil,
                geomean_speedup = result.geomean_speedup,
                best_case = result.best_case,
                worst_case = result.worst_case,
                run_dir = result.run_dir,
                cases = cases,
            })
        end
    end
    for _, comparison in ipairs(abi_comparisons) do
        table.insert(matrix_json.abi_comparisons, {
            base_id = comparison.base_id,
            note = comparison.note,
            mode = comparison.mode,
            gnustep_run_id = comparison.gnustep.id,
            objfw_run_id = comparison.objfw.id,
            objfw_geomean_speedup = comparison.objfw_geomean_speedup,
            best_case = comparison.best_case,
            worst_case = comparison.worst_case,
        })
    end

    io.writefile(path.join(outroot, "matrix.json"), json.encode(matrix_json))
    io.writefile(doc_path, _render_markdown(matrix_kind, doc_path, outroot, samples, warmups, generated_at_utc,
        host_metadata, variants, abi_entries, results_by_id, baselines_by_runtime, ordered_by_speed,
        fastest_by_case, abi_comparisons, failures))

    print(string.format("Generated %s", path.absolute(doc_path)))
    print(string.format("Wrote %s", path.absolute(path.join(outroot, "matrix.json"))))
end
