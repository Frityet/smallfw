import("core.base.option")
import("smallfw.task_helpers")

function main()
    local analyzer = task_helpers.find_required_tool("scan-build",
        "scan-build not found. Install clang-analyzer first.")
    local outdir = option.get("outdir") or path.join("build", "scan-build")
    local clang = task_helpers.clang_program()
    local clangxx = task_helpers.clangxx_program()

    os.rm(outdir)
    os.mkdir(outdir)

    task_helpers.run_xmake(task_helpers.collect_configure_args())

    local args = {
        "--status-bugs",
        "--keep-empty",
        "--use-cc=" .. clang,
        "--use-c++=" .. clangxx,
        "-o", outdir,
        "xmake",
    }
    if option.get("verbose") then
        table.insert(args, "-v")
    end
    table.insert(args, "__scan-build-targets")
    os.execv(analyzer.program, args)
end
