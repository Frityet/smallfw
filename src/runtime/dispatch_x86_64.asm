// any objc_msgSend(id RDI receiver, SEL RSI selector, ...)


.text
.intel_syntax noprefix
.p2align 4
.globl objc_msgSend
.type objc_msgSend,@function
objc_msgSend:
    // the expected behaviour in objc if the obj or the selector is nil is to just return nil
    // this is kinda stupid...
    TEST RDI, RDI
    JE .LNIL_RETURN
    TEST RSI, RSI
    JE .LNIL_RETURN

    // AL will be 1 if we use XMM regs
    TEST AL, AL
    JNZ .LWITH_XMM

.LWITHOUT_XMM:
#if SF_RUNTIME_TAGGED_POINTERS
    MOV R10, RDI
    // The first 3 bits are used for the tag which we use to determine what class the pointer is
    AND R10, 0b111
    JZ .LHEAP_RECEIVER
    // this is where we get the actual class the pointer is
    LEA R11, [RIP + g_tagged_pointer_slot_classes]
    MOV R10, QWORD PTR [R11 + R10*0x8]
    // uh oh! you didnt register your tag :(
    TEST R10, R10
    JE .LNIL_RETURN
    JMP .LCLASS_READY

.LHEAP_RECEIVER:
#endif
    MOV R10, QWORD PTR [RDI]
    TEST R10, R10 // receiver->isa == nil
    JE .LNIL_RETURN
#if SF_RUNTIME_TAGGED_POINTERS
.LCLASS_READY:
#endif

    // caching //
    // this is in case we call the same method multiple times in a row, (i.e for (...) [obj method];)
    // you can see the def in dispatch.c and the type in internal.h.
    /*
        typedef struct SFDispatchEntry {
            Class cls;
            SEL _Nullable sel;
            IMP _Nullable imp;
            uintptr_t reserved;
        } SFDispatchEntry_t;
    */
    // first we have an l0 cache
    // the cache is configured to have 2 entries so that it fits in 64 bytes (one cache line)

#if SF_RUNTIME_THREADSAFE
    CMP R10, QWORD PTR FS:g_dispatch_l0@tpoff
    JNE .LCHECK_L0_SECOND // .cls miss
    CMP RSI, QWORD PTR FS:g_dispatch_l0@tpoff+0x8
    JNE .LCHECK_L0_SECOND // .sel miss
    MOV RAX, QWORD PTR FS:g_dispatch_l0@tpoff+0x10
#else
    CMP R10, QWORD PTR [RIP + g_dispatch_l0]
    JNE .LCHECK_L0_SECOND
    CMP RSI, QWORD PTR [RIP + g_dispatch_l0 + 0x8]
    JNE .LCHECK_L0_SECOND
    MOV RAX, QWORD PTR [RIP + g_dispatch_l0 + 0x10]
#endif
    TEST RAX, RAX // .imp == NULL
    JE .LMISS_WITHOUT_XMM
    LEA R11, [RIP + sf_dispatch_nil_imp]

    CMP RAX, R11 // if the imp is the nil imp...
#if SF_DISPATCH_CACHE_NEGATIVE
    JE .LNIL_RETURN // ...we just return nil
#else
    JE .LMISS_WITHOUT_XMM // ...or we can treat it as a regular cache miss (we have this so that we can have forwarding)
#endif
    // yay! hit!
    JMP RAX

    // checking the second entry in the l0
.LCHECK_L0_SECOND:
#if SF_DISPATCH_L0_DUAL
#if SF_RUNTIME_THREADSAFE
    CMP R10, QWORD PTR FS:g_dispatch_l0@tpoff+0x20
    JNE .LGLOBAL_CACHE
    CMP RSI, QWORD PTR FS:g_dispatch_l0@tpoff+0x28
    JNE .LGLOBAL_CACHE
    MOV RAX, QWORD PTR FS:g_dispatch_l0@tpoff+0x30
#else
    CMP R10, QWORD PTR [RIP + g_dispatch_l0 + 0x20]
    JNE .LGLOBAL_CACHE
    CMP RSI, QWORD PTR [RIP + g_dispatch_l0 + 0x28]
    JNE .LGLOBAL_CACHE
    MOV RAX, QWORD PTR [RIP + g_dispatch_l0 + 0x30]
#endif
    TEST RAX, RAX
    JE .LMISS_WITHOUT_XMM
    LEA R11, [RIP + sf_dispatch_nil_imp]
#if SF_DISPATCH_CACHE_NEGATIVE
    CMP RAX, R11
    JE .LNIL_RETURN
#else
    CMP RAX, R11
    JE .LMISS_WITHOUT_XMM
#endif
    JMP RAX
#endif

.LGLOBAL_CACHE:
    // quick hash to get our index
    MOV RAX, R10 // R10 for the class
    SHR RAX, 0x4
    MOV R11, RSI // RSI for the SEL
    SHR R11, 0x4
    XOR RAX, R11
    MOV R11, RSI
    SHR R11, 0xD
    XOR RAX, R11
    MOV R11, R10
    SHR R11, 0xB
    XOR RAX, R11
#if SF_DISPATCH_CACHE_2WAY
    AND RAX, 0b11111111111
    SHL RAX, 0b110
#else
    AND RAX, 0b0000111111111111
    SHL RAX, 0b101
#endif
    LEA R11, [RIP + g_dispatch_cache]
    ADD R11, RAX

    CMP R10, QWORD PTR [R11]
    JNE .LCHECK_GLOBAL_WAY1
    CMP RSI, QWORD PTR [R11 + 0x8]
    JNE .LCHECK_GLOBAL_WAY1
    // first way hit, grab the imp
    MOV RAX, QWORD PTR [R11 + 0x10]
    TEST RAX, RAX
    JE .LMISS_WITHOUT_XMM
    LEA R11, [RIP + sf_dispatch_nil_imp]
#if SF_DISPATCH_CACHE_NEGATIVE
    CMP RAX, R11
    JE .LGLOBAL_RETURN_NIL
#else
    CMP RAX, R11
    JE .LMISS_WITHOUT_XMM
#endif
    JMP .LGLOBAL_STORE_L0

.LCHECK_GLOBAL_WAY1:
    // another cool optimisation: 2way cache!
    // the idea here is that if we have a miss, but the receiver and selector match on the 2nd we dont need to use the slow path
#if SF_DISPATCH_CACHE_2WAY
    LEA R11, [RIP + g_dispatch_cache]
    ADD R11, RAX
    CMP R10, QWORD PTR [R11 + 0x20]
    JNE .LMISS_WITHOUT_XMM
    CMP RSI, QWORD PTR [R11 + 0x28]
    JNE .LMISS_WITHOUT_XMM
    MOV RAX, QWORD PTR [R11 + 0x30]
    TEST RAX, RAX
    JE .LMISS_WITHOUT_XMM
    LEA R11, [RIP + sf_dispatch_nil_imp]
#if SF_DISPATCH_CACHE_NEGATIVE
    CMP RAX, R11
    JE .LGLOBAL_RETURN_NIL
#else
    CMP RAX, R11
    JE .LMISS_WITHOUT_XMM
#endif
#else
    JMP .LMISS_WITHOUT_XMM
#endif

.LGLOBAL_STORE_L0:
    // promote the global cache hit back into l0 so the next send is basically free

#if SF_RUNTIME_THREADSAFE
#if SF_DISPATCH_L0_DUAL
    // shift the old hot entry down into slot 1 first
    MOV R11, QWORD PTR FS:g_dispatch_l0@tpoff
    MOV QWORD PTR FS:g_dispatch_l0@tpoff+0x20, R11
    MOV R11, QWORD PTR FS:g_dispatch_l0@tpoff+0x8
    MOV QWORD PTR FS:g_dispatch_l0@tpoff+0x28, R11
    MOV R11, QWORD PTR FS:g_dispatch_l0@tpoff+0x10
    MOV QWORD PTR FS:g_dispatch_l0@tpoff+0x30, R11
    MOV R11, QWORD PTR FS:g_dispatch_l0@tpoff+0x18
    MOV QWORD PTR FS:g_dispatch_l0@tpoff+0x38, R11
#endif
    MOV QWORD PTR FS:g_dispatch_l0@tpoff, R10
    MOV QWORD PTR FS:g_dispatch_l0@tpoff+0x8, RSI
    MOV QWORD PTR FS:g_dispatch_l0@tpoff+0x10, RAX
    MOV QWORD PTR FS:g_dispatch_l0@tpoff+0x18, 0
#else
#if SF_DISPATCH_L0_DUAL
    MOV R11, QWORD PTR [RIP + g_dispatch_l0]
    MOV QWORD PTR [RIP + g_dispatch_l0 + 0x20], R11
    MOV R11, QWORD PTR [RIP + g_dispatch_l0 + 0x8]
    MOV QWORD PTR [RIP + g_dispatch_l0 + 0x28], R11
    MOV R11, QWORD PTR [RIP + g_dispatch_l0 + 0x10]
    MOV QWORD PTR [RIP + g_dispatch_l0 + 0x30], R11
    MOV R11, QWORD PTR [RIP + g_dispatch_l0 + 0x18]
    MOV QWORD PTR [RIP + g_dispatch_l0 + 0x38], R11
#endif
    MOV QWORD PTR [RIP + g_dispatch_l0], R10
    MOV QWORD PTR [RIP + g_dispatch_l0 + 0x8], RSI
    MOV QWORD PTR [RIP + g_dispatch_l0 + 0x10], RAX
    MOV QWORD PTR [RIP + g_dispatch_l0 + 0x18], 0
#endif
    JMP RAX

.LGLOBAL_RETURN_NIL:
    // same thing, but this case we are saving the fact that this will always miss
#if SF_RUNTIME_THREADSAFE
#if SF_DISPATCH_L0_DUAL
    MOV R11, QWORD PTR FS:g_dispatch_l0@tpoff
    MOV QWORD PTR FS:g_dispatch_l0@tpoff+0x20, R11
    MOV R11, QWORD PTR FS:g_dispatch_l0@tpoff+0x8
    MOV QWORD PTR FS:g_dispatch_l0@tpoff+0x28, R11
    MOV R11, QWORD PTR FS:g_dispatch_l0@tpoff+0x10
    MOV QWORD PTR FS:g_dispatch_l0@tpoff+0x30, R11
    MOV R11, QWORD PTR FS:g_dispatch_l0@tpoff+0x18
    MOV QWORD PTR FS:g_dispatch_l0@tpoff+0x38, R11
#endif
    MOV QWORD PTR FS:g_dispatch_l0@tpoff, R10
    MOV QWORD PTR FS:g_dispatch_l0@tpoff+0x8, RSI
    MOV QWORD PTR FS:g_dispatch_l0@tpoff+0x10, RAX
    MOV QWORD PTR FS:g_dispatch_l0@tpoff+0x18, 0
#else
#if SF_DISPATCH_L0_DUAL
    MOV R11, QWORD PTR [RIP + g_dispatch_l0]
    MOV QWORD PTR [RIP + g_dispatch_l0 + 0x20], R11
    MOV R11, QWORD PTR [RIP + g_dispatch_l0 + 0x8]
    MOV QWORD PTR [RIP + g_dispatch_l0 + 0x28], R11
    MOV R11, QWORD PTR [RIP + g_dispatch_l0 + 0x10]
    MOV QWORD PTR [RIP + g_dispatch_l0 + 0x30], R11
    MOV R11, QWORD PTR [RIP + g_dispatch_l0 + 0x18]
    MOV QWORD PTR [RIP + g_dispatch_l0 + 0x38], R11
#endif
    MOV QWORD PTR [RIP + g_dispatch_l0], R10
    MOV QWORD PTR [RIP + g_dispatch_l0 + 0x8], RSI
    MOV QWORD PTR [RIP + g_dispatch_l0 + 0x10], RAX
    MOV QWORD PTR [RIP + g_dispatch_l0 + 0x18], 0
#endif
    JMP .LNIL_RETURN

.LMISS_WITHOUT_XMM:
    // now the slow path :(
    SUB RSP, 0x38

    MOV QWORD PTR [RSP], RDI
    MOV QWORD PTR [RSP + 0x8], RSI
    MOV QWORD PTR [RSP + 0x10], RDX
    MOV QWORD PTR [RSP + 0x18], RCX
    MOV QWORD PTR [RSP + 0x20], R8
    MOV QWORD PTR [RSP + 0x28], R9

    LEA RDI, [RSP]
    LEA RSI, [RSP + 8]
    CALL sf_resolve_message_dispatch

    // restore the call frame
    MOV RDI, QWORD PTR [RSP]
    MOV RSI, QWORD PTR [RSP + 0x8]
    MOV RDX, QWORD PTR [RSP + 0x10]
    MOV RCX, QWORD PTR [RSP + 0x18]
    MOV R8, QWORD PTR [RSP + 0x20]
    MOV R9, QWORD PTR [RSP + 0x28]

    // if the resolver misses then we just return nil
    LEA R10, [RIP + sf_dispatch_nil_imp]
    CMP RAX, R10
    JE .LMISS_RETURN_NIL_WITHOUT_XMM

    ADD RSP, 0x38
    JMP RAX // tail call :)

.LMISS_RETURN_NIL_WITHOUT_XMM:
    ADD RSP, 0x38
    JMP .LNIL_RETURN

.LWITH_XMM:
    // same miss path as above, except now we also have vector args to preserve
    SUB RSP, 0xB8

    MOV QWORD PTR [RSP], RDI
    MOV QWORD PTR [RSP + 0x8], RSI
    MOV QWORD PTR [RSP + 0x10], RDX
    MOV QWORD PTR [RSP + 0x18], RCX
    MOV QWORD PTR [RSP + 0x20], R8
    MOV QWORD PTR [RSP + 0x28], R9

    MOVAPS XMMWORD PTR [RSP + 0x30], XMM0
    MOVAPS XMMWORD PTR [RSP + 0x40], XMM1
    MOVAPS XMMWORD PTR [RSP + 0x50], XMM2
    MOVAPS XMMWORD PTR [RSP + 0x60], XMM3
    MOVAPS XMMWORD PTR [RSP + 0x70], XMM4
    MOVAPS XMMWORD PTR [RSP + 0x80], XMM5
    MOVAPS XMMWORD PTR [RSP + 0x90], XMM6
    MOVAPS XMMWORD PTR [RSP + 0xA0], XMM7

    LEA RDI, [RSP]
    LEA RSI, [RSP + 8]
    CALL sf_resolve_message_dispatch

    MOV RDI, QWORD PTR [RSP]
    MOV RSI, QWORD PTR [RSP + 0x8]
    MOV RDX, QWORD PTR [RSP + 0x10]
    MOV RCX, QWORD PTR [RSP + 0x18]
    MOV R8, QWORD PTR [RSP + 0x20]
    MOV R9, QWORD PTR [RSP + 0x28]

    MOVAPS XMM0, XMMWORD PTR [RSP + 0x30]
    MOVAPS XMM1, XMMWORD PTR [RSP + 0x40]
    MOVAPS XMM2, XMMWORD PTR [RSP + 0x50]
    MOVAPS XMM3, XMMWORD PTR [RSP + 0x60]
    MOVAPS XMM4, XMMWORD PTR [RSP + 0x70]
    MOVAPS XMM5, XMMWORD PTR [RSP + 0x80]
    MOVAPS XMM6, XMMWORD PTR [RSP + 0x90]
    MOVAPS XMM7, XMMWORD PTR [RSP + 0xA0]

    LEA R10, [RIP + sf_dispatch_nil_imp]
    CMP RAX, R10
    JE .LMISS_RETURN_NIL_WITH_XMM

    ADD RSP, 0xB8
    JMP RAX

.LMISS_RETURN_NIL_WITH_XMM:
    ADD RSP, 0xB8
    JMP .LNIL_RETURN

.LNIL_RETURN:
    // objc nil messaging wants nil for basically everything
    XOR EAX, EAX
    PXOR XMM0, XMM0
    RET

.size objc_msgSend, .-objc_msgSend

// struct objc_msgSend_stret(struct *RDI out, id RSI receiver, SEL RDX selector, ...)

.globl objc_msgSend_stret
.type objc_msgSend_stret,@function
objc_msgSend_stret:
    // for structs we basically do the same idea, but RDI is the out buffer so receiver/selector shift right by one reg
    TEST RSI, RSI
    JE .LSTRET_RETURN
    TEST RDX, RDX
    JE .LSTRET_RETURN
    TEST AL, AL
    JNZ .LSTRET_WITH_XMM

.LSTRET_WITHOUT_XMM:
#if SF_RUNTIME_TAGGED_POINTERS
    MOV R10, RSI
    AND R10, 0b111
    JZ .LSTRET_HEAP_RECEIVER
    LEA R11, [RIP + g_tagged_pointer_slot_classes]
    MOV R10, QWORD PTR [R11 + R10*0x8]
    TEST R10, R10
    JE .LSTRET_RETURN
    JMP .LSTRET_CLASS_READY

.LSTRET_HEAP_RECEIVER:
#endif
    MOV R10, QWORD PTR [RSI]
    TEST R10, R10
    JE .LSTRET_RETURN
#if SF_RUNTIME_TAGGED_POINTERS
.LSTRET_CLASS_READY:
#endif

    // same l0 cache lookup, except the key is now (class, selector) in (R10, RDX)
#if SF_RUNTIME_THREADSAFE
    CMP R10, QWORD PTR FS:g_dispatch_l0@tpoff
    JNE .LSTRET_CHECK_L0_SECOND
    CMP RDX, QWORD PTR FS:g_dispatch_l0@tpoff+0x8
    JNE .LSTRET_CHECK_L0_SECOND
    MOV RAX, QWORD PTR FS:g_dispatch_l0@tpoff+0x10
#else
    CMP R10, QWORD PTR [RIP + g_dispatch_l0]
    JNE .LSTRET_CHECK_L0_SECOND
    CMP RDX, QWORD PTR [RIP + g_dispatch_l0 + 0x8]
    JNE .LSTRET_CHECK_L0_SECOND
    MOV RAX, QWORD PTR [RIP + g_dispatch_l0 + 0x10]
#endif
    TEST RAX, RAX
    JE .LSTRET_MISS_WITHOUT_XMM
    LEA R11, [RIP + sf_dispatch_nil_imp]
#if SF_DISPATCH_CACHE_NEGATIVE
    CMP RAX, R11
    JE .LSTRET_RETURN
#else
    CMP RAX, R11
    JE .LSTRET_MISS_WITHOUT_XMM
#endif
    JMP RAX

.LSTRET_CHECK_L0_SECOND:
#if SF_DISPATCH_L0_DUAL
#if SF_RUNTIME_THREADSAFE
    CMP R10, QWORD PTR FS:g_dispatch_l0@tpoff+0x20
    JNE .LSTRET_GLOBAL_CACHE
    CMP RDX, QWORD PTR FS:g_dispatch_l0@tpoff+0x28
    JNE .LSTRET_GLOBAL_CACHE
    MOV RAX, QWORD PTR FS:g_dispatch_l0@tpoff+0x30
#else
    CMP R10, QWORD PTR [RIP + g_dispatch_l0 + 0x20]
    JNE .LSTRET_GLOBAL_CACHE
    CMP RDX, QWORD PTR [RIP + g_dispatch_l0 + 0x28]
    JNE .LSTRET_GLOBAL_CACHE
    MOV RAX, QWORD PTR [RIP + g_dispatch_l0 + 0x30]
#endif
    TEST RAX, RAX
    JE .LSTRET_MISS_WITHOUT_XMM
    LEA R11, [RIP + sf_dispatch_nil_imp]
#if SF_DISPATCH_CACHE_NEGATIVE
    CMP RAX, R11
    JE .LSTRET_RETURN
#else
    CMP RAX, R11
    JE .LSTRET_MISS_WITHOUT_XMM
#endif
    JMP RAX
#endif

.LSTRET_GLOBAL_CACHE:
    MOV RAX, R10
    SHR RAX, 0b100
    MOV R11, RDX
    SHR R11, 0b100
    XOR RAX, R11
    MOV R11, RDX
    SHR R11, 0b1101
    XOR RAX, R11
    MOV R11, R10
    SHR R11, 0b1011
    XOR RAX, R11
    #if SF_DISPATCH_CACHE_2WAY
    AND RAX, 0b11111111111
    SHL RAX, 0b110
    #else
    AND RAX, 0b111111111111
    SHL RAX, 0b101
    #endif
    LEA R11, [RIP + g_dispatch_cache]
    ADD R11, RAX

    CMP R10, QWORD PTR [R11]
    JNE .LSTRET_CHECK_GLOBAL_WAY1
    CMP RDX, QWORD PTR [R11 + 0x8]
    JNE .LSTRET_CHECK_GLOBAL_WAY1

    MOV RAX, QWORD PTR [R11 + 0x10]
    TEST RAX, RAX
    JE .LSTRET_MISS_WITHOUT_XMM
    LEA R11, [RIP + sf_dispatch_nil_imp]
#if SF_DISPATCH_CACHE_NEGATIVE
    CMP RAX, R11
    JE .LSTRET_GLOBAL_RETURN_NIL
#else
    CMP RAX, R11
    JE .LSTRET_MISS_WITHOUT_XMM
#endif
    JMP .LSTRET_GLOBAL_STORE_L0

.LSTRET_CHECK_GLOBAL_WAY1:

#if SF_DISPATCH_CACHE_2WAY
    LEA R11, [RIP + g_dispatch_cache]
    ADD R11, RAX
    CMP R10, QWORD PTR [R11 + 0x20]
    JNE .LSTRET_MISS_WITHOUT_XMM
    CMP RDX, QWORD PTR [R11 + 0x28]
    JNE .LSTRET_MISS_WITHOUT_XMM
    MOV RAX, QWORD PTR [R11 + 0x30]
    TEST RAX, RAX
    JE .LSTRET_MISS_WITHOUT_XMM
    LEA R11, [RIP + sf_dispatch_nil_imp]
#if SF_DISPATCH_CACHE_NEGATIVE
    CMP RAX, R11
    JE .LSTRET_GLOBAL_RETURN_NIL
#else
    CMP RAX, R11
    JE .LSTRET_MISS_WITHOUT_XMM
#endif
#else
    JMP .LSTRET_MISS_WITHOUT_XMM
#endif

.LSTRET_GLOBAL_STORE_L0:
#if SF_RUNTIME_THREADSAFE
#if SF_DISPATCH_L0_DUAL
    MOV R11, QWORD PTR FS:g_dispatch_l0@tpoff
    MOV QWORD PTR FS:g_dispatch_l0@tpoff+0x20, R11
    MOV R11, QWORD PTR FS:g_dispatch_l0@tpoff+0x8
    MOV QWORD PTR FS:g_dispatch_l0@tpoff+0x28, R11
    MOV R11, QWORD PTR FS:g_dispatch_l0@tpoff+0x10
    MOV QWORD PTR FS:g_dispatch_l0@tpoff+0x30, R11
    MOV R11, QWORD PTR FS:g_dispatch_l0@tpoff+0x18
    MOV QWORD PTR FS:g_dispatch_l0@tpoff+56, R11
#endif
    MOV QWORD PTR FS:g_dispatch_l0@tpoff, R10
    MOV QWORD PTR FS:g_dispatch_l0@tpoff+0x8, RDX
    MOV QWORD PTR FS:g_dispatch_l0@tpoff+0x10, RAX
    MOV QWORD PTR FS:g_dispatch_l0@tpoff+0x18, 0
#else
#if SF_DISPATCH_L0_DUAL
    MOV R11, QWORD PTR [RIP + g_dispatch_l0]
    MOV QWORD PTR [RIP + g_dispatch_l0 + 0x20], R11
    MOV R11, QWORD PTR [RIP + g_dispatch_l0 + 0x8]
    MOV QWORD PTR [RIP + g_dispatch_l0 + 0x28], R11
    MOV R11, QWORD PTR [RIP + g_dispatch_l0 + 0x10]
    MOV QWORD PTR [RIP + g_dispatch_l0 + 0x30], R11
    MOV R11, QWORD PTR [RIP + g_dispatch_l0 + 0x18]
    MOV QWORD PTR [RIP + g_dispatch_l0 + 0x38], R11
#endif
    MOV QWORD PTR [RIP + g_dispatch_l0], R10
    MOV QWORD PTR [RIP + g_dispatch_l0 + 0x8], RDX
    MOV QWORD PTR [RIP + g_dispatch_l0 + 0x10], RAX
    MOV QWORD PTR [RIP + g_dispatch_l0 + 0x18], 0
#endif
    JMP RAX

.LSTRET_GLOBAL_RETURN_NIL:
#if SF_RUNTIME_THREADSAFE
#if SF_DISPATCH_L0_DUAL
    MOV R11, QWORD PTR FS:g_dispatch_l0@tpoff
    MOV QWORD PTR FS:g_dispatch_l0@tpoff+0x20, R11
    MOV R11, QWORD PTR FS:g_dispatch_l0@tpoff+0x8
    MOV QWORD PTR FS:g_dispatch_l0@tpoff+0x28, R11
    MOV R11, QWORD PTR FS:g_dispatch_l0@tpoff+0x10
    MOV QWORD PTR FS:g_dispatch_l0@tpoff+0x30, R11
    MOV R11, QWORD PTR FS:g_dispatch_l0@tpoff+0x18
    MOV QWORD PTR FS:g_dispatch_l0@tpoff+0x38, R11
#endif
    MOV QWORD PTR FS:g_dispatch_l0@tpoff, R10
    MOV QWORD PTR FS:g_dispatch_l0@tpoff+0x8, RDX
    MOV QWORD PTR FS:g_dispatch_l0@tpoff+0x10, RAX
    MOV QWORD PTR FS:g_dispatch_l0@tpoff+0x18, 0
#else
#if SF_DISPATCH_L0_DUAL
    MOV R11, QWORD PTR [RIP + g_dispatch_l0]
    MOV QWORD PTR [RIP + g_dispatch_l0 + 0x20], R11
    MOV R11, QWORD PTR [RIP + g_dispatch_l0 + 0x8]
    MOV QWORD PTR [RIP + g_dispatch_l0 + 0x28], R11
    MOV R11, QWORD PTR [RIP + g_dispatch_l0 + 0x10]
    MOV QWORD PTR [RIP + g_dispatch_l0 + 0x30], R11
    MOV R11, QWORD PTR [RIP + g_dispatch_l0 + 0x18]
    MOV QWORD PTR [RIP + g_dispatch_l0 + 0x38], R11
#endif
    MOV QWORD PTR [RIP + g_dispatch_l0], R10
    MOV QWORD PTR [RIP + g_dispatch_l0 + 0x8], RDX
    MOV QWORD PTR [RIP + g_dispatch_l0 + 0x10], RAX
    MOV QWORD PTR [RIP + g_dispatch_l0 + 0x18], 0
#endif
    JMP .LSTRET_RETURN

.LSTRET_MISS_WITHOUT_XMM:
    // slow path again, but the resolver wants receiver/selector after the stret out pointer
    SUB RSP, 0x38

    MOV QWORD PTR [RSP], RDI
    MOV QWORD PTR [RSP + 0x8], RSI
    MOV QWORD PTR [RSP + 0x10], RDX
    MOV QWORD PTR [RSP + 0x18], RCX
    MOV QWORD PTR [RSP + 0x20], R8
    MOV QWORD PTR [RSP + 0x28], R9

    LEA RDI, [RSP + 0x8]
    LEA RSI, [RSP + 0x10]
    CALL sf_resolve_message_dispatch

    MOV RDI, QWORD PTR [RSP]
    MOV RSI, QWORD PTR [RSP + 0x8]
    MOV RDX, QWORD PTR [RSP + 0x10]
    MOV RCX, QWORD PTR [RSP + 0x18]
    MOV R8, QWORD PTR [RSP + 0x20]
    MOV R9, QWORD PTR [RSP + 0x28]

    LEA R10, [RIP + sf_dispatch_nil_imp]
    CMP RAX, R10
    JE .LSTRET_RETURN_MISS_WITHOUT_XMM

    ADD RSP, 0x38
    JMP RAX

.LSTRET_RETURN_MISS_WITHOUT_XMM:
    ADD RSP, 0x38
    JMP .LSTRET_RETURN

.LSTRET_WITH_XMM:
    SUB RSP, 0xB8

    MOV QWORD PTR [RSP], RDI
    MOV QWORD PTR [RSP + 0x8], RSI
    MOV QWORD PTR [RSP + 0x10], RDX
    MOV QWORD PTR [RSP + 0x18], RCX
    MOV QWORD PTR [RSP + 0x20], R8
    MOV QWORD PTR [RSP + 0x28], R9

    MOVAPS XMMWORD PTR [RSP + 0x30], XMM0
    MOVAPS XMMWORD PTR [RSP + 0x40], XMM1
    MOVAPS XMMWORD PTR [RSP + 0x50], XMM2
    MOVAPS XMMWORD PTR [RSP + 0x60], XMM3
    MOVAPS XMMWORD PTR [RSP + 0x70], XMM4
    MOVAPS XMMWORD PTR [RSP + 0x80], XMM5
    MOVAPS XMMWORD PTR [RSP + 0x90], XMM6
    MOVAPS XMMWORD PTR [RSP + 0xA0], XMM7

    LEA RDI, [RSP + 0x8]
    LEA RSI, [RSP + 0x10]
    CALL sf_resolve_message_dispatch

    MOV RDI, QWORD PTR [RSP]
    MOV RSI, QWORD PTR [RSP + 0x8]
    MOV RDX, QWORD PTR [RSP + 0x10]
    MOV RCX, QWORD PTR [RSP + 0x18]
    MOV R8, QWORD PTR [RSP + 0x20]
    MOV R9, QWORD PTR [RSP + 0x28]

    MOVAPS XMM0, XMMWORD PTR [RSP + 0x30]
    MOVAPS XMM1, XMMWORD PTR [RSP + 0x40]
    MOVAPS XMM2, XMMWORD PTR [RSP + 0x50]
    MOVAPS XMM3, XMMWORD PTR [RSP + 0x60]
    MOVAPS XMM4, XMMWORD PTR [RSP + 0x70]
    MOVAPS XMM5, XMMWORD PTR [RSP + 0x80]
    MOVAPS XMM6, XMMWORD PTR [RSP + 0x90]
    MOVAPS XMM7, XMMWORD PTR [RSP + 0xA0]

    LEA R10, [RIP + sf_dispatch_nil_imp]
    CMP RAX, R10
    JE .LSTRET_RETURN_MISS_WITH_XMM

    ADD RSP, 0xB8
    JMP RAX

.LSTRET_RETURN_MISS_WITH_XMM:
    ADD RSP, 0xB8
    JMP .LSTRET_RETURN

.LSTRET_RETURN:
    // the out buffer already holds the result for stret, so we just leave
    RET

.size objc_msgSend_stret, .-objc_msgSend_stret
.att_syntax prefix
