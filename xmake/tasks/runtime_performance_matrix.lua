local function define_runtime_performance_matrix_task(name)
    task(name)
        set_category("tool")
        set_menu {
            usage = "xmake " .. name .. " [options]",
            description = "Run the runtime benchmark matrix across the selected Objective-C ABIs and generate measured markdown docs. The default matrix is the full Linux x86_64 coverage set.",
            options = {
                {nil, "matrix", "kv", "full", "Select the benchmark matrix to run.", " - full", " - curated"},
                {"s", "samples", "kv", nil, "Number of recorded samples per variant. Defaults to 5 for --matrix=full and 1 for --matrix=curated."},
                {"w", "warmups", "kv", nil, "Number of warmup runs per variant. Defaults to 1 for --matrix=full and 0 for --matrix=curated."},
                {nil, "objc-runtimes", "kv", "both", "Select which Objective-C ABIs to benchmark.", " - both", " - gnustep-2.3", " - objfw-1.5"},
                {"O", "outdir", "kv", nil, "Set the matrix artifact root. Defaults depend on --matrix."},
                {"d", "doc", "kv", nil, "Set the generated markdown output path. Defaults depend on --matrix."},
            }
        }
        on_run(function ()
            local runner = import("smallfw.tasks.runtime_performance_matrix")
            runner.main()
        end)
    task_end()
end

define_runtime_performance_matrix_task("run-runtime-performance-matrix")
define_runtime_performance_matrix_task("run-runtime-perf-matrix")
