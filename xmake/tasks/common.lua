smallfw = smallfw or {}

function smallfw.runtime_config_menu_options(extra_options, defaults)
    defaults = defaults or {}
    local options = {
        {"m", "mode", "kv", defaults.mode or "debug", "Set build mode."},
        {"p", "plat", "kv", defaults.plat, "Set target platform."},
        {"a", "arch", "kv", defaults.arch, "Set target architecture."},
        {"o", "builddir", "kv", nil, "Set xmake build directory."},
        {},
        {nil, "analysis-symbols", "kv", nil, "Override analysis-symbols.", " - y", " - n"},
        {},
        {nil, "objc-runtime", "kv", nil, "Override objc-runtime.", " - gnustep-2.3", " - objfw-1.5"},
        {nil, "dispatch-backend", "kv", nil, "Override dispatch-backend.", " - asm", " - c"},
        {nil, "runtime-exceptions", "kv", nil, "Override runtime-exceptions.", " - y", " - n"},
        {nil, "runtime-reflection", "kv", nil, "Override runtime-reflection.", " - y", " - n"},
        {nil, "runtime-forwarding", "kv", nil, "Override runtime-forwarding.", " - y", " - n"},
        {nil, "runtime-validation", "kv", nil, "Override runtime-validation.", " - y", " - n"},
        {nil, "runtime-tagged-pointers", "kv", nil, "Override runtime-tagged-pointers.", " - y", " - n"},
        {nil, "runtime-sanitize", "kv", nil, "Override runtime-sanitize.", " - y", " - n"},
        {},
        {nil, "runtime-native-tuning", "kv", nil, "Override runtime-native-tuning.", " - y", " - n"},
        {nil, "runtime-thinlto", "kv", nil, "Override runtime-thinlto.", " - y", " - n"},
        {nil, "runtime-full-lto", "kv", nil, "Override runtime-full-lto.", " - y", " - n"},
        {nil, "runtime-compact-headers", "kv", nil, "Override runtime-compact-headers.", " - y", " - n"},
        {nil, "runtime-inline-value-storage", "kv", nil, "Override runtime-inline-value-storage.", " - y", " - n"},
        {nil, "runtime-inline-group-state", "kv", nil, "Override runtime-inline-group-state.", " - y", " - n"},
    }

    for _, entry in ipairs(extra_options or {}) do
        table.insert(options, entry)
    end
    return options
end
