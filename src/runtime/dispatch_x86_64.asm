// any objc_msgSend(id RDI receiver, SEL RSI selector, ...)

.text
.intel_syntax noprefix
.p2align 4

.globl objc_msgSend
.type objc_msgSend,@function
objc_msgSend:
#if SF_RUNTIME_TAGGED_POINTERS
    MOV R10, RDI
    AND R10, 0b111 // The first 3 bits are used for the tag which we use to determine what class the pointer is
    JZ .LMSG_HEAP_RECEIVER // oh no, not tagged :(
    LEA R11, [RIP + g_tagged_pointer_slot_classes]
    MOV R10, QWORD PTR [R11 + R10*0x8]
    JMP .LMSG_CLASS_READY

.LMSG_HEAP_RECEIVER:
#endif
    MOV R10, QWORD PTR [RDI]

#if SF_RUNTIME_TAGGED_POINTERS
.LMSG_CLASS_READY:
#endif
    MOV R11, QWORD PTR [RSI]
    MOV EAX, DWORD PTR [R11 - 0x8]
    MOV R10, QWORD PTR [R10 + 0x40]
    MOV RAX, QWORD PTR [R10 + RAX*0x8]

#if SF_RUNTIME_FORWARDING
    TEST RAX, RAX
    JE .LMSG_MISS // oh no, not found :(
#endif
    JMP RAX

#if SF_RUNTIME_FORWARDING
.LMSG_MISS:
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
    ADD RSP, 0xB8
    JMP RAX
#endif

.size objc_msgSend, .-objc_msgSend

// struct objc_msgSend_stret(struct *RDI out, id RSI receiver, SEL RDX selector, ...)

.globl objc_msgSend_stret
.type objc_msgSend_stret,@function
objc_msgSend_stret:
#if SF_RUNTIME_TAGGED_POINTERS
    MOV R10, RSI
    AND R10, 0b111
    JZ .LSTRET_HEAP_RECEIVER
    LEA R11, [RIP + g_tagged_pointer_slot_classes]
    MOV R10, QWORD PTR [R11 + R10*0x8]
    JMP .LSTRET_CLASS_READY

.LSTRET_HEAP_RECEIVER:
#endif
    MOV R10, QWORD PTR [RSI]

#if SF_RUNTIME_TAGGED_POINTERS
.LSTRET_CLASS_READY:
#endif
    MOV R11, QWORD PTR [RDX]
    MOV EAX, DWORD PTR [R11 - 0x8]
    MOV R10, QWORD PTR [R10 + 0x40]
    MOV RAX, QWORD PTR [R10 + RAX*0x8]

#if SF_RUNTIME_FORWARDING
    TEST RAX, RAX
    JE .LSTRET_MISS
#endif
    JMP RAX

#if SF_RUNTIME_FORWARDING
.LSTRET_MISS:
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
    ADD RSP, 0xB8
    JMP RAX
#endif

.size objc_msgSend_stret, .-objc_msgSend_stret
.att_syntax prefix
