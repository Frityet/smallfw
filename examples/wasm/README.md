# WASM Runtime Smoke Example

This example keeps the WebAssembly path simple: it exercises the SmallFW
runtime directly and writes its results to stdout without any JavaScript bridge
or browser bindings.

It shows:
- plain Objective-C object allocation compiled to WebAssembly
- parent-linked allocations with `allocWithParent:`
- built-in runtime reflection like `class_getName()` and `isKindOfClass:`
- output that works in both Node and the generated browser smoke page

Build and run it with:

```sh
xmake f -p wasm -a wasm32 -m debug
xmake build wasm-runtime-smoke
xmake run wasm-runtime-smoke
```

Open the generated browser page at:

```sh
build/wasm/wasm32/debug/wasm-runtime-smoke.html
```
