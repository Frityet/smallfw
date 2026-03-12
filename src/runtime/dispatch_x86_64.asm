.text
.intel_syntax noprefix
.p2align 4
.globl objc_msgSend
.type objc_msgSend,@function
objc_msgSend:
    TEST RDI, RDI
    JE .LNIL_RETURN
    TEST RSI, RSI
    JE .LNIL_RETURN

    TEST AL, AL
    JNZ .LWITH_XMM

.LWITHOUT_XMM:
#if SF_RUNTIME_TAGGED_POINTERS
    MOV R10, RDI
    AND R10, 7
    JZ .LHEAP_RECEIVER
    LEA R11, [RIP + g_tagged_pointer_slot_classes]
    MOV R10, QWORD PTR [R11 + R10*8]
    TEST R10, R10
    JE .LNIL_RETURN
    JMP .LCLASS_READY

.LHEAP_RECEIVER:
#endif
    MOV R10, QWORD PTR [RDI]
    TEST R10, R10
    JE .LNIL_RETURN
#if SF_RUNTIME_TAGGED_POINTERS
.LCLASS_READY:
#endif

#if SF_RUNTIME_THREADSAFE
    CMP R10, QWORD PTR FS:g_dispatch_l0@tpoff
    JNE .LCHECK_L0_SECOND
    CMP RSI, QWORD PTR FS:g_dispatch_l0+8@tpoff
    JNE .LCHECK_L0_SECOND
    MOV RAX, QWORD PTR FS:g_dispatch_l0+16@tpoff
#else
    CMP R10, QWORD PTR [RIP + g_dispatch_l0]
    JNE .LCHECK_L0_SECOND
    CMP RSI, QWORD PTR [RIP + g_dispatch_l0 + 8]
    JNE .LCHECK_L0_SECOND
    MOV RAX, QWORD PTR [RIP + g_dispatch_l0 + 16]
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

.LCHECK_L0_SECOND:
#if SF_DISPATCH_L0_DUAL
#if SF_RUNTIME_THREADSAFE
    CMP R10, QWORD PTR FS:g_dispatch_l0+32@tpoff
    JNE .LGLOBAL_CACHE
    CMP RSI, QWORD PTR FS:g_dispatch_l0+40@tpoff
    JNE .LGLOBAL_CACHE
    MOV RAX, QWORD PTR FS:g_dispatch_l0+48@tpoff
#else
    CMP R10, QWORD PTR [RIP + g_dispatch_l0 + 32]
    JNE .LGLOBAL_CACHE
    CMP RSI, QWORD PTR [RIP + g_dispatch_l0 + 40]
    JNE .LGLOBAL_CACHE
    MOV RAX, QWORD PTR [RIP + g_dispatch_l0 + 48]
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
    MOV RAX, R10
    SHR RAX, 4
    MOV R11, RSI
    SHR R11, 4
    XOR RAX, R11
    MOV R11, RSI
    SHR R11, 13
    XOR RAX, R11
    MOV R11, R10
    SHR R11, 11
    XOR RAX, R11
    #if SF_DISPATCH_CACHE_2WAY
    AND RAX, 2047
    SHL RAX, 6
    #else
    AND RAX, 4095
    SHL RAX, 5
    #endif
    LEA R11, [RIP + g_dispatch_cache]
    ADD R11, RAX

    CMP R10, QWORD PTR [R11]
    JNE .LCHECK_GLOBAL_WAY1
    CMP RSI, QWORD PTR [R11 + 8]
    JNE .LCHECK_GLOBAL_WAY1
    MOV RAX, QWORD PTR [R11 + 16]
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
#if SF_DISPATCH_CACHE_2WAY
    LEA R11, [RIP + g_dispatch_cache]
    ADD R11, RAX
    CMP R10, QWORD PTR [R11 + 32]
    JNE .LMISS_WITHOUT_XMM
    CMP RSI, QWORD PTR [R11 + 40]
    JNE .LMISS_WITHOUT_XMM
    MOV RAX, QWORD PTR [R11 + 48]
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

#if SF_RUNTIME_THREADSAFE
#if SF_DISPATCH_L0_DUAL
    MOV R11, QWORD PTR FS:g_dispatch_l0@tpoff
    MOV QWORD PTR FS:g_dispatch_l0+32@tpoff, R11
    MOV R11, QWORD PTR FS:g_dispatch_l0+8@tpoff
    MOV QWORD PTR FS:g_dispatch_l0+40@tpoff, R11
    MOV R11, QWORD PTR FS:g_dispatch_l0+16@tpoff
    MOV QWORD PTR FS:g_dispatch_l0+48@tpoff, R11
    MOV R11, QWORD PTR FS:g_dispatch_l0+24@tpoff
    MOV QWORD PTR FS:g_dispatch_l0+56@tpoff, R11
#endif
    MOV QWORD PTR FS:g_dispatch_l0@tpoff, R10
    MOV QWORD PTR FS:g_dispatch_l0+8@tpoff, RSI
    MOV QWORD PTR FS:g_dispatch_l0+16@tpoff, RAX
    MOV QWORD PTR FS:g_dispatch_l0+24@tpoff, 0
#else
#if SF_DISPATCH_L0_DUAL
    MOV R11, QWORD PTR [RIP + g_dispatch_l0]
    MOV QWORD PTR [RIP + g_dispatch_l0 + 32], R11
    MOV R11, QWORD PTR [RIP + g_dispatch_l0 + 8]
    MOV QWORD PTR [RIP + g_dispatch_l0 + 40], R11
    MOV R11, QWORD PTR [RIP + g_dispatch_l0 + 16]
    MOV QWORD PTR [RIP + g_dispatch_l0 + 48], R11
    MOV R11, QWORD PTR [RIP + g_dispatch_l0 + 24]
    MOV QWORD PTR [RIP + g_dispatch_l0 + 56], R11
#endif
    MOV QWORD PTR [RIP + g_dispatch_l0], R10
    MOV QWORD PTR [RIP + g_dispatch_l0 + 8], RSI
    MOV QWORD PTR [RIP + g_dispatch_l0 + 16], RAX
    MOV QWORD PTR [RIP + g_dispatch_l0 + 24], 0
#endif
    JMP RAX

.LGLOBAL_RETURN_NIL:
#if SF_RUNTIME_THREADSAFE
#if SF_DISPATCH_L0_DUAL
    MOV R11, QWORD PTR FS:g_dispatch_l0@tpoff
    MOV QWORD PTR FS:g_dispatch_l0+32@tpoff, R11
    MOV R11, QWORD PTR FS:g_dispatch_l0+8@tpoff
    MOV QWORD PTR FS:g_dispatch_l0+40@tpoff, R11
    MOV R11, QWORD PTR FS:g_dispatch_l0+16@tpoff
    MOV QWORD PTR FS:g_dispatch_l0+48@tpoff, R11
    MOV R11, QWORD PTR FS:g_dispatch_l0+24@tpoff
    MOV QWORD PTR FS:g_dispatch_l0+56@tpoff, R11
#endif
    MOV QWORD PTR FS:g_dispatch_l0@tpoff, R10
    MOV QWORD PTR FS:g_dispatch_l0+8@tpoff, RSI
    MOV QWORD PTR FS:g_dispatch_l0+16@tpoff, RAX
    MOV QWORD PTR FS:g_dispatch_l0+24@tpoff, 0
#else
#if SF_DISPATCH_L0_DUAL
    MOV R11, QWORD PTR [RIP + g_dispatch_l0]
    MOV QWORD PTR [RIP + g_dispatch_l0 + 32], R11
    MOV R11, QWORD PTR [RIP + g_dispatch_l0 + 8]
    MOV QWORD PTR [RIP + g_dispatch_l0 + 40], R11
    MOV R11, QWORD PTR [RIP + g_dispatch_l0 + 16]
    MOV QWORD PTR [RIP + g_dispatch_l0 + 48], R11
    MOV R11, QWORD PTR [RIP + g_dispatch_l0 + 24]
    MOV QWORD PTR [RIP + g_dispatch_l0 + 56], R11
#endif
    MOV QWORD PTR [RIP + g_dispatch_l0], R10
    MOV QWORD PTR [RIP + g_dispatch_l0 + 8], RSI
    MOV QWORD PTR [RIP + g_dispatch_l0 + 16], RAX
    MOV QWORD PTR [RIP + g_dispatch_l0 + 24], 0
#endif
    JMP .LNIL_RETURN

.LMISS_WITHOUT_XMM:
    SUB RSP, 0x38

    MOV QWORD PTR [RSP], RDI
    MOV QWORD PTR [RSP + 8], RSI
    MOV QWORD PTR [RSP + 16], RDX
    MOV QWORD PTR [RSP + 24], RCX
    MOV QWORD PTR [RSP + 32], R8
    MOV QWORD PTR [RSP + 40], R9

    LEA RDI, [RSP]
    LEA RSI, [RSP + 8]
    CALL sf_resolve_message_dispatch

    MOV RDI, QWORD PTR [RSP]
    MOV RSI, QWORD PTR [RSP + 8]
    MOV RDX, QWORD PTR [RSP + 16]
    MOV RCX, QWORD PTR [RSP + 24]
    MOV R8, QWORD PTR [RSP + 32]
    MOV R9, QWORD PTR [RSP + 40]

    LEA R10, [RIP + sf_dispatch_nil_imp]
    CMP RAX, R10
    JE .LMISS_RETURN_NIL_WITHOUT_XMM

    ADD RSP, 0x38
    JMP RAX

.LMISS_RETURN_NIL_WITHOUT_XMM:
    ADD RSP, 0x38
    JMP .LNIL_RETURN

.LWITH_XMM:
    SUB RSP, 0xB8

    MOV QWORD PTR [RSP], RDI
    MOV QWORD PTR [RSP + 8], RSI
    MOV QWORD PTR [RSP + 16], RDX
    MOV QWORD PTR [RSP + 24], RCX
    MOV QWORD PTR [RSP + 32], R8
    MOV QWORD PTR [RSP + 40], R9

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
    MOV RSI, QWORD PTR [RSP + 8]
    MOV RDX, QWORD PTR [RSP + 16]
    MOV RCX, QWORD PTR [RSP + 24]
    MOV R8, QWORD PTR [RSP + 32]
    MOV R9, QWORD PTR [RSP + 40]

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
    XOR EAX, EAX
    PXOR XMM0, XMM0
    RET

.size objc_msgSend, .-objc_msgSend

.globl objc_msgSend_stret
.type objc_msgSend_stret,@function
objc_msgSend_stret:
    TEST RSI, RSI
    JE .LSTRET_RETURN
    TEST RDX, RDX
    JE .LSTRET_RETURN

    TEST AL, AL
    JNZ .LSTRET_WITH_XMM

.LSTRET_WITHOUT_XMM:
#if SF_RUNTIME_TAGGED_POINTERS
    MOV R10, RSI
    AND R10, 7
    JZ .LSTRET_HEAP_RECEIVER
    LEA R11, [RIP + g_tagged_pointer_slot_classes]
    MOV R10, QWORD PTR [R11 + R10*8]
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

#if SF_RUNTIME_THREADSAFE
    CMP R10, QWORD PTR FS:g_dispatch_l0@tpoff
    JNE .LSTRET_CHECK_L0_SECOND
    CMP RDX, QWORD PTR FS:g_dispatch_l0+8@tpoff
    JNE .LSTRET_CHECK_L0_SECOND
    MOV RAX, QWORD PTR FS:g_dispatch_l0+16@tpoff
#else
    CMP R10, QWORD PTR [RIP + g_dispatch_l0]
    JNE .LSTRET_CHECK_L0_SECOND
    CMP RDX, QWORD PTR [RIP + g_dispatch_l0 + 8]
    JNE .LSTRET_CHECK_L0_SECOND
    MOV RAX, QWORD PTR [RIP + g_dispatch_l0 + 16]
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
    CMP R10, QWORD PTR FS:g_dispatch_l0+32@tpoff
    JNE .LSTRET_GLOBAL_CACHE
    CMP RDX, QWORD PTR FS:g_dispatch_l0+40@tpoff
    JNE .LSTRET_GLOBAL_CACHE
    MOV RAX, QWORD PTR FS:g_dispatch_l0+48@tpoff
#else
    CMP R10, QWORD PTR [RIP + g_dispatch_l0 + 32]
    JNE .LSTRET_GLOBAL_CACHE
    CMP RDX, QWORD PTR [RIP + g_dispatch_l0 + 40]
    JNE .LSTRET_GLOBAL_CACHE
    MOV RAX, QWORD PTR [RIP + g_dispatch_l0 + 48]
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
    SHR RAX, 4
    MOV R11, RDX
    SHR R11, 4
    XOR RAX, R11
    MOV R11, RDX
    SHR R11, 13
    XOR RAX, R11
    MOV R11, R10
    SHR R11, 11
    XOR RAX, R11
    #if SF_DISPATCH_CACHE_2WAY
    AND RAX, 2047
    SHL RAX, 6
    #else
    AND RAX, 4095
    SHL RAX, 5
    #endif
    LEA R11, [RIP + g_dispatch_cache]
    ADD R11, RAX

    CMP R10, QWORD PTR [R11]
    JNE .LSTRET_CHECK_GLOBAL_WAY1
    CMP RDX, QWORD PTR [R11 + 8]
    JNE .LSTRET_CHECK_GLOBAL_WAY1
    MOV RAX, QWORD PTR [R11 + 16]
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
    CMP R10, QWORD PTR [R11 + 32]
    JNE .LSTRET_MISS_WITHOUT_XMM
    CMP RDX, QWORD PTR [R11 + 40]
    JNE .LSTRET_MISS_WITHOUT_XMM
    MOV RAX, QWORD PTR [R11 + 48]
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
    MOV QWORD PTR FS:g_dispatch_l0+32@tpoff, R11
    MOV R11, QWORD PTR FS:g_dispatch_l0+8@tpoff
    MOV QWORD PTR FS:g_dispatch_l0+40@tpoff, R11
    MOV R11, QWORD PTR FS:g_dispatch_l0+16@tpoff
    MOV QWORD PTR FS:g_dispatch_l0+48@tpoff, R11
    MOV R11, QWORD PTR FS:g_dispatch_l0+24@tpoff
    MOV QWORD PTR FS:g_dispatch_l0+56@tpoff, R11
#endif
    MOV QWORD PTR FS:g_dispatch_l0@tpoff, R10
    MOV QWORD PTR FS:g_dispatch_l0+8@tpoff, RDX
    MOV QWORD PTR FS:g_dispatch_l0+16@tpoff, RAX
    MOV QWORD PTR FS:g_dispatch_l0+24@tpoff, 0
#else
#if SF_DISPATCH_L0_DUAL
    MOV R11, QWORD PTR [RIP + g_dispatch_l0]
    MOV QWORD PTR [RIP + g_dispatch_l0 + 32], R11
    MOV R11, QWORD PTR [RIP + g_dispatch_l0 + 8]
    MOV QWORD PTR [RIP + g_dispatch_l0 + 40], R11
    MOV R11, QWORD PTR [RIP + g_dispatch_l0 + 16]
    MOV QWORD PTR [RIP + g_dispatch_l0 + 48], R11
    MOV R11, QWORD PTR [RIP + g_dispatch_l0 + 24]
    MOV QWORD PTR [RIP + g_dispatch_l0 + 56], R11
#endif
    MOV QWORD PTR [RIP + g_dispatch_l0], R10
    MOV QWORD PTR [RIP + g_dispatch_l0 + 8], RDX
    MOV QWORD PTR [RIP + g_dispatch_l0 + 16], RAX
    MOV QWORD PTR [RIP + g_dispatch_l0 + 24], 0
#endif
    JMP RAX

.LSTRET_GLOBAL_RETURN_NIL:
#if SF_RUNTIME_THREADSAFE
#if SF_DISPATCH_L0_DUAL
    MOV R11, QWORD PTR FS:g_dispatch_l0@tpoff
    MOV QWORD PTR FS:g_dispatch_l0+32@tpoff, R11
    MOV R11, QWORD PTR FS:g_dispatch_l0+8@tpoff
    MOV QWORD PTR FS:g_dispatch_l0+40@tpoff, R11
    MOV R11, QWORD PTR FS:g_dispatch_l0+16@tpoff
    MOV QWORD PTR FS:g_dispatch_l0+48@tpoff, R11
    MOV R11, QWORD PTR FS:g_dispatch_l0+24@tpoff
    MOV QWORD PTR FS:g_dispatch_l0+56@tpoff, R11
#endif
    MOV QWORD PTR FS:g_dispatch_l0@tpoff, R10
    MOV QWORD PTR FS:g_dispatch_l0+8@tpoff, RDX
    MOV QWORD PTR FS:g_dispatch_l0+16@tpoff, RAX
    MOV QWORD PTR FS:g_dispatch_l0+24@tpoff, 0
#else
#if SF_DISPATCH_L0_DUAL
    MOV R11, QWORD PTR [RIP + g_dispatch_l0]
    MOV QWORD PTR [RIP + g_dispatch_l0 + 32], R11
    MOV R11, QWORD PTR [RIP + g_dispatch_l0 + 8]
    MOV QWORD PTR [RIP + g_dispatch_l0 + 40], R11
    MOV R11, QWORD PTR [RIP + g_dispatch_l0 + 16]
    MOV QWORD PTR [RIP + g_dispatch_l0 + 48], R11
    MOV R11, QWORD PTR [RIP + g_dispatch_l0 + 24]
    MOV QWORD PTR [RIP + g_dispatch_l0 + 56], R11
#endif
    MOV QWORD PTR [RIP + g_dispatch_l0], R10
    MOV QWORD PTR [RIP + g_dispatch_l0 + 8], RDX
    MOV QWORD PTR [RIP + g_dispatch_l0 + 16], RAX
    MOV QWORD PTR [RIP + g_dispatch_l0 + 24], 0
#endif
    JMP .LSTRET_RETURN

.LSTRET_MISS_WITHOUT_XMM:
    SUB RSP, 0x38

    MOV QWORD PTR [RSP], RDI
    MOV QWORD PTR [RSP + 8], RSI
    MOV QWORD PTR [RSP + 16], RDX
    MOV QWORD PTR [RSP + 24], RCX
    MOV QWORD PTR [RSP + 32], R8
    MOV QWORD PTR [RSP + 40], R9

    LEA RDI, [RSP + 8]
    LEA RSI, [RSP + 16]
    CALL sf_resolve_message_dispatch

    MOV RDI, QWORD PTR [RSP]
    MOV RSI, QWORD PTR [RSP + 8]
    MOV RDX, QWORD PTR [RSP + 16]
    MOV RCX, QWORD PTR [RSP + 24]
    MOV R8, QWORD PTR [RSP + 32]
    MOV R9, QWORD PTR [RSP + 40]

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
    MOV QWORD PTR [RSP + 8], RSI
    MOV QWORD PTR [RSP + 16], RDX
    MOV QWORD PTR [RSP + 24], RCX
    MOV QWORD PTR [RSP + 32], R8
    MOV QWORD PTR [RSP + 40], R9

    MOVAPS XMMWORD PTR [RSP + 0x30], XMM0
    MOVAPS XMMWORD PTR [RSP + 0x40], XMM1
    MOVAPS XMMWORD PTR [RSP + 0x50], XMM2
    MOVAPS XMMWORD PTR [RSP + 0x60], XMM3
    MOVAPS XMMWORD PTR [RSP + 0x70], XMM4
    MOVAPS XMMWORD PTR [RSP + 0x80], XMM5
    MOVAPS XMMWORD PTR [RSP + 0x90], XMM6
    MOVAPS XMMWORD PTR [RSP + 0xA0], XMM7

    LEA RDI, [RSP + 8]
    LEA RSI, [RSP + 16]
    CALL sf_resolve_message_dispatch

    MOV RDI, QWORD PTR [RSP]
    MOV RSI, QWORD PTR [RSP + 8]
    MOV RDX, QWORD PTR [RSP + 16]
    MOV RCX, QWORD PTR [RSP + 24]
    MOV R8, QWORD PTR [RSP + 32]
    MOV R9, QWORD PTR [RSP + 40]

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
    RET

.size objc_msgSend_stret, .-objc_msgSend_stret
.att_syntax prefix
