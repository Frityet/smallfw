import("core.base.option")
import("smallfw.task_helpers")

function main()
    local configure_args = task_helpers.collect_configure_args()
    local check_args = {"check", "clang.tidy"}

    task_helpers.run_xmake(configure_args)
    task_helpers.run_xmake({"project", "-k", "compile_commands"})

    if option.get("tidy_checks") then
        table.insert(check_args, "--checks=" .. option.get("tidy_checks"))
    end
    if option.get("tidy_configfile") then
        table.insert(check_args, "--configfile=" .. option.get("tidy_configfile"))
    end
    if option.get("tidy_create") then
        table.insert(check_args, "--create")
    end
    if option.get("tidy_fix") then
        table.insert(check_args, "--fix")
    end
    if option.get("tidy_fix_errors") then
        table.insert(check_args, "--fix_errors")
    end
    if option.get("tidy_fix_notes") then
        table.insert(check_args, "--fix_notes")
    end
    if option.get("tidy_file") then
        table.insert(check_args, "-f")
        table.insert(check_args, option.get("tidy_file"))
    end
    if option.get("tidy_target") then
        table.insert(check_args, option.get("tidy_target"))
    end

    task_helpers.run_xmake(check_args)
end
