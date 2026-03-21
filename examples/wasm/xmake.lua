if not smallfw.is_wasm() then
    return
end

target("wasm-runtime-smoke")
    set_group("examples/wasm")
    smallfw.configure_runtime_binary_target({
        includedirs = {
            smallfw.project_path("src"),
            smallfw.project_path("examples/wasm"),
        },
    })
    smallfw.add_wasm_browser_smoke_page({title = "smallfw wasm runtime smoke"})
    add_files("main.m", {mflags = {"-fno-objc-arc"}})
