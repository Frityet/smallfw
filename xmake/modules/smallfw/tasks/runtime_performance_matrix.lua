import("core.base.json")
import("core.base.option")
import("smallfw.task_helpers")

local CASE_ORDER = {
    "dispatch_monomorphic_hot",
    "dispatch_polymorphic_hot",
    "dispatch_nil_receiver_hot",
    "arc_retain_release_heap",
    "arc_retain_release_round_robin",
    "arc_store_strong_cycle",
    "alloc_init_release_plain",
    "parent_group_cycle",
}

local CASE_TITLES = {
    dispatch_monomorphic_hot = "dispatch_monomorphic_hot",
    dispatch_polymorphic_hot = "dispatch_polymorphic_hot",
    dispatch_nil_receiver_hot = "dispatch_nil_receiver_hot",
    arc_retain_release_heap = "arc_retain_release_heap",
    arc_retain_release_round_robin = "arc_retain_release_round_robin",
    arc_store_strong_cycle = "arc_store_strong_cycle",
    alloc_init_release_plain = "alloc_init_release_plain",
    parent_group_cycle = "parent_group_cycle",
}

local VARIANTS = {
    {
        id = "debug-default",
        category = "Modes",
        mode = "debug",
        note = "Debug build with runtime defaults.",
    },
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
        options = {["analysis-symbols"] = "y"},
        note = "Default release stack with PGO and BOLT.",
    },
    {
        id = "release-max-opt",
        category = "Whole-program",
        options = {
            ["runtime-native-tuning"] = "y",
            ["runtime-thinlto"] = "y",
            ["dispatch-l0-dual"] = "y",
            ["dispatch-cache-2way"] = "y",
            ["dispatch-cache-negative"] = "y",
            ["runtime-compact-headers"] = "y",
            ["runtime-fast-objects"] = "y",
            ["runtime-inline-value-storage"] = "y",
            ["runtime-inline-group-state"] = "y",
        },
        note = "Recommended tuned release stack without profile feedback.",
    },
    {
        id = "release-max-opt-pgo",
        category = "Whole-program",
        pgo = "use",
        options = {
            ["runtime-native-tuning"] = "y",
            ["runtime-thinlto"] = "y",
            ["dispatch-l0-dual"] = "y",
            ["dispatch-cache-2way"] = "y",
            ["dispatch-cache-negative"] = "y",
            ["runtime-compact-headers"] = "y",
            ["runtime-fast-objects"] = "y",
            ["runtime-inline-value-storage"] = "y",
            ["runtime-inline-group-state"] = "y",
        },
        note = "Recommended tuned release stack with PGO.",
    },
    {
        id = "release-max-opt-pgo-bolt",
        category = "Whole-program",
        pgo = "use",
        bolt = "on",
        options = {
            ["analysis-symbols"] = "y",
            ["runtime-native-tuning"] = "y",
            ["runtime-thinlto"] = "y",
            ["dispatch-l0-dual"] = "y",
            ["dispatch-cache-2way"] = "y",
            ["dispatch-cache-negative"] = "y",
            ["runtime-compact-headers"] = "y",
            ["runtime-fast-objects"] = "y",
            ["runtime-inline-value-storage"] = "y",
            ["runtime-inline-group-state"] = "y",
        },
        note = "Recommended tuned release stack with PGO and BOLT.",
    },
    {
        id = "release-dispatch-c",
        category = "Dispatch / behavior",
        options = {["dispatch-backend"] = "c"},
        note = "Uses the C message send path instead of the assembly fast path.",
    },
    {
        id = "release-dispatch-stats",
        category = "Dispatch / behavior",
        options = {["dispatch-stats"] = "y"},
        note = "Enables dispatch cache statistics counters.",
    },
    {
        id = "release-forwarding",
        category = "Dispatch / behavior",
        options = {["runtime-forwarding"] = "y"},
        note = "Enables forwarding and runtime selector resolution.",
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
        id = "release-threadsafe",
        category = "Dispatch / behavior",
        options = {["runtime-threadsafe"] = "y"},
        note = "Adds synchronized runtime bookkeeping.",
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
        id = "release-dispatch-l0-dual",
        category = "Dispatch / behavior",
        options = {["dispatch-l0-dual"] = "y"},
        note = "Enables the dual-entry L0 dispatch cache.",
    },
    {
        id = "release-dispatch-cache-2way",
        category = "Dispatch / behavior",
        options = {["dispatch-cache-2way"] = "y"},
        note = "Enables a 2-way dispatch cache.",
    },
    {
        id = "release-dispatch-cache-negative",
        category = "Dispatch / behavior",
        options = {
            ["dispatch-cache-2way"] = "y",
            ["dispatch-cache-negative"] = "y",
        },
        note = "Enables negative cache entries and its 2-way cache prerequisite.",
    },
    {
        id = "release-compact-headers",
        category = "Layout / ABI",
        options = {["runtime-compact-headers"] = "y"},
        note = "Uses the compact runtime object header layout.",
    },
    {
        id = "release-fast-objects",
        category = "Layout / ABI",
        options = {
            ["runtime-compact-headers"] = "y",
            ["runtime-fast-objects"] = "y",
        },
        note = "Enables FastObject paths and the compact-header prerequisite.",
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
    {
        id = "release-sanitize",
        category = "Instrumentation",
        options = {["runtime-sanitize"] = "y"},
        note = "AddressSanitizer and UndefinedBehaviorSanitizer enabled.",
    },
}

local DISPLAY_OPTION_ORDER = {
    "analysis-symbols",
    "runtime-threadsafe",
    "dispatch-backend",
    "dispatch-stats",
    "runtime-exceptions",
    "runtime-reflection",
    "runtime-forwarding",
    "runtime-validation",
    "runtime-tagged-pointers",
    "runtime-sanitize",
    "runtime-native-tuning",
    "runtime-thinlto",
    "runtime-full-lto",
    "dispatch-l0-dual",
    "dispatch-cache-2way",
    "dispatch-cache-negative",
    "runtime-compact-headers",
    "runtime-fast-objects",
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

local function _effective_options(variant)
    local options = {["analysis-symbols"] = "n"}
    if (variant.bolt or "off") == "on" then
        options["analysis-symbols"] = "y"
    end
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

local function _run_variant(rootdir, samples, warmups, variant)
    local run_dir = path.join(rootdir, "runs", variant.id)
    os.tryrm(run_dir)
    task_helpers.run_xmake(_bench_command_args(rootdir, samples, warmups, variant))

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
        category = variant.category,
        note = variant.note,
        mode = variant.mode or "release",
        pgo = variant.pgo or "off",
        bolt = variant.bolt or "off",
        options = _effective_options(variant),
        changed_options = _visible_changed_options(variant),
        run_dir = path.absolute(run_dir),
        summary = summary,
        metadata = metadata,
        cases = cases,
    }
end

local function _derive_relative_metrics(results_by_id)
    local baseline = assert(results_by_id["release-default"], "release-default baseline is required")
    local fastest_by_case = {}
    local ordered_results = {}
    for _, variant in ipairs(VARIANTS) do
        local result = results_by_id[variant.id]
        if result ~= nil then
            table.insert(ordered_results, result)
        end
    end

    for _, result in ipairs(ordered_results) do
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
                    variant = result.id,
                    mean_ns_per = current_case.mean_ns_per,
                    speedup = speedup,
                }
            end
        end
        result.geomean_speedup = _geomean(speedups)
        result.best_case = best
        result.worst_case = worst
    end

    table.sort(ordered_results, function (a, b)
        if a.geomean_speedup == b.geomean_speedup then
            return a.id < b.id
        end
        return a.geomean_speedup > b.geomean_speedup
    end)

    return baseline, fastest_by_case, ordered_results
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

local function _render_markdown(doc_path, outroot, samples, warmups, generated_at_utc, host_metadata, results_by_id,
                                ordered_by_speed, fastest_by_case, failures)
    local lines = {}
    local baseline = results_by_id["release-default"]
    local failures_by_id = _failure_by_id(failures)

    _markdown_header(lines, 1, "Runtime Performance Matrix")
    table.insert(lines,
        "This document is generated from measured `xmake run-runtime-bench` runs on the current host. The matrix uses `analysis-symbols=n` by default so release rows reflect a shipping-style binary unless a row explicitly says otherwise.")
    table.insert(lines, "")
    table.insert(lines, string.format("Generated at: `%s`", generated_at_utc))
    table.insert(lines, string.format("Regenerate with: `xmake run-runtime-performance-matrix --samples=%d --warmups=%d --outdir=%s --doc=%s`",
        samples, warmups, outroot, doc_path))
    table.insert(lines, "")

    _markdown_header(lines, 2, "Environment")
    table.insert(lines, string.format("- Host: `%s`", host_metadata.host.host or os.host()))
    table.insert(lines, string.format("- Architecture: `%s`", host_metadata.host.arch or os.arch()))
    if host_metadata.host.uname ~= nil then
        table.insert(lines, string.format("- `uname -srvm`: `%s`", host_metadata.host.uname))
    end
    if host_metadata.host.clang ~= nil then
        table.insert(lines, string.format("- `clang --version`: `%s`", _single_line(host_metadata.host.clang) or "unknown"))
    end
    if host_metadata.host.xmake ~= nil then
        table.insert(lines, string.format("- `xmake --version`: `%s`", _single_line(host_metadata.host.xmake) or "unknown"))
    end
    table.insert(lines, string.format("- Samples per variant: `%d`", samples))
    table.insert(lines, string.format("- Warmups per variant: `%d`", warmups))
    table.insert(lines, string.format("- Benchmark artifact root: `%s`", path.absolute(outroot)))
    table.insert(lines, "")

    _markdown_header(lines, 2, "Variant Definitions")
    local variant_rows = {}
    for _, variant in ipairs(VARIANTS) do
        local result = results_by_id[variant.id]
        local failure = failures_by_id[variant.id]
        local options = result and result.changed_options or _visible_changed_options(variant)
        table.insert(variant_rows, {
            "`" .. variant.id .. "`",
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
    _append_table(lines, {"Variant", "Category", "Mode", "PGO", "BOLT", "Changed Options", "Status", "Failure", "Notes"}, variant_rows)

    _markdown_header(lines, 2, "Leaderboard")
    local leaderboard_rows = {}
    for rank, result in ipairs(ordered_by_speed) do
        table.insert(leaderboard_rows, {
            tostring(rank),
            "`" .. result.id .. "`",
            result.category,
            _format_speedup(result.geomean_speedup),
            string.format("`%s` (%s)", result.best_case.case, _format_speedup(result.best_case.speedup)),
            string.format("`%s` (%s)", result.worst_case.case, _format_speedup(result.worst_case.speedup)),
            result.note,
        })
    end
    _append_table(lines, {"Rank", "Variant", "Category", "Geo Mean vs `release-default`", "Best Case", "Worst Case", "Notes"}, leaderboard_rows)

    _markdown_header(lines, 2, "Fastest Variant Per Benchmark")
    local fastest_rows = {}
    for _, case_name in ipairs(CASE_ORDER) do
        local fastest = fastest_by_case[case_name]
        table.insert(fastest_rows, {
            "`" .. CASE_TITLES[case_name] .. "`",
            "`" .. fastest.variant .. "`",
            _format_ns(fastest.mean_ns_per),
            _format_speedup(fastest.speedup),
        })
    end
    _append_table(lines, {"Benchmark", "Fastest Variant", "Mean", "Speedup vs `release-default`"}, fastest_rows)

    if results_by_id["release-default"] ~= nil and results_by_id["release-dispatch-c"] ~= nil then
        _markdown_header(lines, 2, "ASM vs C Backend")
        local asm_rows = {}
        local asm_result = results_by_id["release-default"]
        local c_result = results_by_id["release-dispatch-c"]
        for _, case_name in ipairs(CASE_ORDER) do
            local asm_case = asm_result.cases[case_name]
            local c_case = c_result.cases[case_name]
            table.insert(asm_rows, {
                "`" .. CASE_TITLES[case_name] .. "`",
                _format_ns(asm_case.mean_ns_per),
                _format_ns(c_case.mean_ns_per),
                _format_speedup(c_case.mean_ns_per / asm_case.mean_ns_per),
            })
        end
        _append_table(lines, {"Benchmark", "ASM Mean", "C Mean", "ASM Advantage"}, asm_rows)
    end

    _markdown_header(lines, 2, "Per-Benchmark Results")
    for _, case_name in ipairs(CASE_ORDER) do
        _markdown_header(lines, 3, CASE_TITLES[case_name])
        local rows = {}
        for _, variant in ipairs(VARIANTS) do
            local result = results_by_id[variant.id]
            if result ~= nil then
                local case_result = result.cases[case_name]
                table.insert(rows, {
                    "`" .. result.id .. "`",
                    _format_ns(case_result.mean_ns_per),
                    _format_speedup(case_result.speedup_vs_baseline),
                    result.category,
                    result.note,
                })
            end
        end
        _append_table(lines, {"Variant", "Mean", "Speedup vs `release-default`", "Category", "Notes"}, rows)
    end

    if #failures > 0 then
        _markdown_header(lines, 2, "Failed Variants")
        for _, failure in ipairs(failures) do
            table.insert(lines, string.format("- `%s`: `%s`", failure.id, failure.error:gsub("\n", " ")))
        end
        table.insert(lines, "")
    end

    _markdown_header(lines, 2, "Baseline Reference")
    table.insert(lines, string.format("`release-default` artifacts: `%s`", baseline.run_dir))
    table.insert(lines, "")

    return table.concat(lines, "\n")
end

function main()
    assert(os.host() == "linux", "run-runtime-performance-matrix is only supported on Linux hosts.")

    local samples = _positive_integer_option("samples", 1)
    local warmups = _nonnegative_integer_option("warmups", 0)
    local outroot = _string_option("outdir", path.join("build", "runtime-analysis", "performance-matrix"))
    local doc_path = _string_option("doc", path.join("docs", "PERFORMANCE.md"))

    os.mkdir(outroot)
    os.mkdir(path.join(outroot, "runs"))
    os.mkdir(path.directory(doc_path))

    local results_by_id = {}
    local failures = {}

    for index, variant in ipairs(VARIANTS) do
        print(string.format("[%d/%d] %s", index, #VARIANTS, variant.id))
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
                error = _single_line(tostring(errs or _variant_failure_message(outroot, variant))) or "unknown error",
            })
        end
    end

    assert(results_by_id["release-default"] ~= nil, "the release-default baseline failed, so the matrix cannot be rendered")

    local baseline, fastest_by_case, ordered_by_speed = _derive_relative_metrics(results_by_id)
    local generated_at_utc = os.date("!%Y-%m-%dT%H:%M:%SZ")
    local host_metadata = baseline.metadata or {}
    local matrix_json = {
        generated_at_utc = generated_at_utc,
        outroot = path.absolute(outroot),
        samples = samples,
        warmups = warmups,
        variants = {},
        failures = failures,
    }
    for _, variant in ipairs(VARIANTS) do
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
                category = result.category,
                note = result.note,
                mode = result.mode,
                pgo = result.pgo,
                bolt = result.bolt,
                changed_options = result.changed_options,
                geomean_speedup = result.geomean_speedup,
                best_case = result.best_case,
                worst_case = result.worst_case,
                run_dir = result.run_dir,
                cases = cases,
            })
        end
    end

    io.writefile(path.join(outroot, "matrix.json"), json.encode(matrix_json))
    io.writefile(doc_path, _render_markdown(doc_path, outroot, samples, warmups, generated_at_utc, host_metadata,
        results_by_id, ordered_by_speed, fastest_by_case, failures))

    print(string.format("Generated %s", path.absolute(doc_path)))
    print(string.format("Wrote %s", path.absolute(path.join(outroot, "matrix.json"))))
end
