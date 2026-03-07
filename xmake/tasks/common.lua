function smallfw_runtime_config_menu_options(extra_options, defaults)
    defaults = defaults or {}
    local options = {
        {"m", "mode", "kv", defaults.mode or "debug", "Set build mode."},
        {"p", "plat", "kv", defaults.plat, "Set target platform."},
        {"a", "arch", "kv", defaults.arch, "Set target architecture."},
        {"o", "builddir", "kv", nil, "Set xmake build directory."},
        {},
        {nil, "runtime_threadsafe", "kv", nil, "Override runtime_threadsafe.", " - y", " - n"},
        {nil, "dispatch_backend", "kv", nil, "Override dispatch_backend.", " - asm", " - c"},
        {nil, "dispatch_stats", "kv", nil, "Override dispatch_stats.", " - y", " - n"},
        {nil, "runtime_exceptions", "kv", nil, "Override runtime_exceptions.", " - y", " - n"},
        {nil, "runtime_reflection", "kv", nil, "Override runtime_reflection.", " - y", " - n"},
        {nil, "runtime_validation", "kv", nil, "Override runtime_validation.", " - y", " - n"},
        {nil, "runtime_sanitize", "kv", nil, "Override runtime_sanitize.", " - y", " - n"},
        {nil, "runtime_slim_alloc", "kv", nil, "Override runtime_slim_alloc.", " - y", " - n"},
    }

    for _, entry in ipairs(extra_options or {}) do
        table.insert(options, entry)
    end
    return options
end
