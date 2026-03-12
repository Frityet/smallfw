local function define_runtime_performance_matrix_task(name)
    task(name)
        set_category("tool")
        set_menu {
            usage = "xmake " .. name .. " [options]",
            description = "Run a broad runtime benchmark matrix and generate docs/PERFORMANCE.md from measured results.",
            options = {
                {"s", "samples", "kv", "1", "Number of recorded samples per variant."},
                {"w", "warmups", "kv", "0", "Number of warmup runs per variant."},
                {"O", "outdir", "kv", "build/runtime-analysis/performance-matrix", "Set the matrix artifact root."},
                {"d", "doc", "kv", "docs/PERFORMANCE.md", "Set the generated markdown output path."},
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
