// SysV:  any objc_msgSend(id RDI receiver, SEL RSI selector, ...)
// Win64: any objc_msgSend(id RCX receiver, SEL RDX selector, ...)

.text
.intel_syntax noprefix
.p2align 4

#ifdef __APPLE__
#    define SF_SYMBOL(name) _##name
#    define SF_TYPE(name)
#    define SF_SIZE(name)
#elif defined(_WIN32)
#    define SF_SYMBOL(name) name
#    define SF_TYPE(name)
#    define SF_SIZE(name)
#    define SF_CLASS_DTABLE_OFFSET 0x38
#else
#    define SF_SYMBOL(name) name
#    define SF_TYPE(name) .type name,@function
#    define SF_SIZE(name) .size name, .-name
#    define SF_CLASS_DTABLE_OFFSET 0x40
#endif

.globl SF_SYMBOL(objc_msgSend)
SF_TYPE(objc_msgSend)
SF_SYMBOL(objc_msgSend):
#if SF_RUNTIME_TAGGED_POINTERS
#    if defined(_WIN32)
        MOV R10, RCX
#    else
        MOV R10, RDI
#    endif
        AND R10, 0b111 // The first 3 bits are used for the tag which we use to determine what class the pointer is
        JZ .LMSG_HEAP_RECEIVER // oh no, not tagged :(
        LEA R11, [RIP + SF_SYMBOL(g_tagged_pointer_slot_classes)]
        MOV R10, QWORD PTR [R11 + R10*0x8]
        JMP .LMSG_CLASS_READY

    .LMSG_HEAP_RECEIVER:
#endif
#if defined(_WIN32)
    MOV R10, QWORD PTR [RCX]
#else
    MOV R10, QWORD PTR [RDI]
#endif

#if SF_RUNTIME_TAGGED_POINTERS
    .LMSG_CLASS_READY:
#endif
#if defined(_WIN32)
    MOV R11, QWORD PTR [RDX]
#else
    MOV R11, QWORD PTR [RSI]
#endif
    MOV EAX, DWORD PTR [R11 - 0x8]
    MOV R10, QWORD PTR [R10 + SF_CLASS_DTABLE_OFFSET]
    MOV RAX, QWORD PTR [R10 + RAX*0x8]

#if SF_RUNTIME_FORWARDING
        TEST RAX, RAX
        JE .LMSG_MISS // oh no, not found :(
#endif
    JMP RAX

#if SF_RUNTIME_FORWARDING
    .LMSG_MISS:
#    if defined(_WIN32)
        SUB RSP, 0xC8
        MOV QWORD PTR [RSP + 0x20], RCX
        MOV QWORD PTR [RSP + 0x28], RDX
        MOV QWORD PTR [RSP + 0x30], R8
        MOV QWORD PTR [RSP + 0x38], R9

        MOVAPS XMMWORD PTR [RSP + 0x40], XMM0
        MOVAPS XMMWORD PTR [RSP + 0x50], XMM1
        MOVAPS XMMWORD PTR [RSP + 0x60], XMM2
        MOVAPS XMMWORD PTR [RSP + 0x70], XMM3
        MOVAPS XMMWORD PTR [RSP + 0x80], XMM4
        MOVAPS XMMWORD PTR [RSP + 0x90], XMM5
        MOVAPS XMMWORD PTR [RSP + 0xA0], XMM6
        MOVAPS XMMWORD PTR [RSP + 0xB0], XMM7

        LEA RCX, [RSP + 0x20]
        LEA RDX, [RSP + 0x28]
        CALL SF_SYMBOL(sf_resolve_message_dispatch)

        MOV RCX, QWORD PTR [RSP + 0x20]
        MOV RDX, QWORD PTR [RSP + 0x28]
        MOV R8, QWORD PTR [RSP + 0x30]
        MOV R9, QWORD PTR [RSP + 0x38]
        MOVAPS XMM0, XMMWORD PTR [RSP + 0x40]
        MOVAPS XMM1, XMMWORD PTR [RSP + 0x50]
        MOVAPS XMM2, XMMWORD PTR [RSP + 0x60]
        MOVAPS XMM3, XMMWORD PTR [RSP + 0x70]
        MOVAPS XMM4, XMMWORD PTR [RSP + 0x80]
        MOVAPS XMM5, XMMWORD PTR [RSP + 0x90]
        MOVAPS XMM6, XMMWORD PTR [RSP + 0xA0]
        MOVAPS XMM7, XMMWORD PTR [RSP + 0xB0]
        ADD RSP, 0xC8
        JMP RAX
#    else
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
        LEA RSI, [RSP + 0x8]
        //regular miss
        //TODO: test to see if splitting an XMM path and a regular path is faster
        CALL SF_SYMBOL(sf_resolve_message_dispatch)

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
        ADD RSP, 0xB8
        JMP RAX
#    endif
#endif

SF_SIZE(objc_msgSend)

// SysV:  struct objc_msgSend_stret(struct *RDI out, id RSI receiver, SEL RDX selector, ...)
// Win64: struct objc_msgSend_stret(struct *RCX out, id RDX receiver, SEL R8 selector, ...)

.globl SF_SYMBOL(objc_msgSend_stret)
SF_TYPE(objc_msgSend_stret)
SF_SYMBOL(objc_msgSend_stret):
#if SF_RUNTIME_TAGGED_POINTERS
#    if defined(_WIN32)
        MOV R10, RDX
#    else
        MOV R10, RSI
#    endif
        AND R10, 0b111
        JZ .LSTRET_HEAP_RECEIVER
        LEA R11, [RIP + SF_SYMBOL(g_tagged_pointer_slot_classes)]
        MOV R10, QWORD PTR [R11 + R10*0x8]
        JMP .LSTRET_CLASS_READY

    .LSTRET_HEAP_RECEIVER:
#endif
#if defined(_WIN32)
    MOV R10, QWORD PTR [RDX]
#else
    MOV R10, QWORD PTR [RSI]
#endif

#if SF_RUNTIME_TAGGED_POINTERS
    .LSTRET_CLASS_READY:
#endif
#if defined(_WIN32)
    MOV R11, QWORD PTR [R8]
#else
    MOV R11, QWORD PTR [RDX]
#endif
    MOV EAX, DWORD PTR [R11 - 0x8]
    MOV R10, QWORD PTR [R10 + SF_CLASS_DTABLE_OFFSET]
    MOV RAX, QWORD PTR [R10 + RAX*0x8]

#if SF_RUNTIME_FORWARDING
        TEST RAX, RAX
        JE .LSTRET_MISS
#endif
    JMP RAX

#if SF_RUNTIME_FORWARDING
    .LSTRET_MISS:
#    if defined(_WIN32)
        SUB RSP, 0xC8
        MOV QWORD PTR [RSP + 0x20], RCX
        MOV QWORD PTR [RSP + 0x28], RDX
        MOV QWORD PTR [RSP + 0x30], R8
        MOV QWORD PTR [RSP + 0x38], R9

        MOVAPS XMMWORD PTR [RSP + 0x40], XMM0
        MOVAPS XMMWORD PTR [RSP + 0x50], XMM1
        MOVAPS XMMWORD PTR [RSP + 0x60], XMM2
        MOVAPS XMMWORD PTR [RSP + 0x70], XMM3
        MOVAPS XMMWORD PTR [RSP + 0x80], XMM4
        MOVAPS XMMWORD PTR [RSP + 0x90], XMM5
        MOVAPS XMMWORD PTR [RSP + 0xA0], XMM6
        MOVAPS XMMWORD PTR [RSP + 0xB0], XMM7

        LEA RCX, [RSP + 0x28]
        LEA RDX, [RSP + 0x30]
        CALL SF_SYMBOL(sf_resolve_message_dispatch)

        MOV RCX, QWORD PTR [RSP + 0x20]
        MOV RDX, QWORD PTR [RSP + 0x28]
        MOV R8, QWORD PTR [RSP + 0x30]
        MOV R9, QWORD PTR [RSP + 0x38]
        MOVAPS XMM0, XMMWORD PTR [RSP + 0x40]
        MOVAPS XMM1, XMMWORD PTR [RSP + 0x50]
        MOVAPS XMM2, XMMWORD PTR [RSP + 0x60]
        MOVAPS XMM3, XMMWORD PTR [RSP + 0x70]
        MOVAPS XMM4, XMMWORD PTR [RSP + 0x80]
        MOVAPS XMM5, XMMWORD PTR [RSP + 0x90]
        MOVAPS XMM6, XMMWORD PTR [RSP + 0xA0]
        MOVAPS XMM7, XMMWORD PTR [RSP + 0xB0]
        ADD RSP, 0xC8
        JMP RAX
#    else
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
        CALL SF_SYMBOL(sf_resolve_message_dispatch)

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
        ADD RSP, 0xB8
        JMP RAX
#    endif
#endif

SF_SIZE(objc_msgSend_stret)
.att_syntax prefix
