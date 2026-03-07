.text
.p2align 4
.globl objc_msgSend
.type objc_msgSend,@function
objc_msgSend:
    testq %rdi, %rdi
    je .Lnil_return
    testq %rsi, %rsi
    je .Lnil_return

    testb %al, %al
    jnz .Lwith_xmm

.Lwithout_xmm:
    movq (%rdi), %r10
    testq %r10, %r10
    je .Lnil_return

#if SF_RUNTIME_THREADSAFE
    cmpq %r10, %fs:g_dispatch_l0@tpoff
    jne .Lglobal_cache
    cmpq %rsi, %fs:g_dispatch_l0+8@tpoff
    jne .Lglobal_cache
    movq %fs:g_dispatch_l0+16@tpoff, %rax
#else
    cmpq %r10, g_dispatch_l0(%rip)
    jne .Lglobal_cache
    cmpq %rsi, g_dispatch_l0+8(%rip)
    jne .Lglobal_cache
    movq g_dispatch_l0+16(%rip), %rax
#endif
    testq %rax, %rax
    je .Lmiss_without_xmm
    jmp *%rax

.Lglobal_cache:
    movq %r10, %rax
    shrq $4, %rax
    movq %rsi, %r11
    shrq $4, %r11
    xorq %r11, %rax
    movq %r11, %r10
    shrq $9, %r10
    xorq %r10, %rax
    movq (%rdi), %r10
    shrq $11, %r10
    xorq %r10, %rax
    andq $4095, %rax
    shlq $5, %rax
    leaq g_dispatch_cache(%rip), %r11
    addq %rax, %r11

    movq (%rdi), %r10
    cmpq %r10, 0x00(%r11)
    jne .Lmiss_without_xmm
    cmpq %rsi, 0x08(%r11)
    jne .Lmiss_without_xmm
    movq 0x10(%r11), %rax
    testq %rax, %rax
    je .Lmiss_without_xmm

#if SF_RUNTIME_THREADSAFE
    movq %r10, %fs:g_dispatch_l0@tpoff
    movq %rsi, %fs:g_dispatch_l0+8@tpoff
    movq %rax, %fs:g_dispatch_l0+16@tpoff
    movq $0, %fs:g_dispatch_l0+24@tpoff
#else
    movq %r10, g_dispatch_l0(%rip)
    movq %rsi, g_dispatch_l0+8(%rip)
    movq %rax, g_dispatch_l0+16(%rip)
    movq $0, g_dispatch_l0+24(%rip)
#endif
    jmp *%rax

.Lmiss_without_xmm:
    subq $0x38, %rsp

    movq %rdi, 0x00(%rsp)
    movq %rsi, 0x08(%rsp)
    movq %rdx, 0x10(%rsp)
    movq %rcx, 0x18(%rsp)
    movq %r8,  0x20(%rsp)
    movq %r9,  0x28(%rsp)

    movq 0x00(%rsp), %rdi
    movq 0x08(%rsp), %rsi
    movq (%rdi), %rdi
    call sf_lookup_imp_miss

    movq 0x00(%rsp), %rdi
    movq 0x08(%rsp), %rsi
    movq 0x10(%rsp), %rdx
    movq 0x18(%rsp), %rcx
    movq 0x20(%rsp), %r8
    movq 0x28(%rsp), %r9

    addq $0x38, %rsp
    jmp *%rax

.Lwith_xmm:
    subq $0xb8, %rsp

    movq %rdi, 0x00(%rsp)
    movq %rsi, 0x08(%rsp)
    movq %rdx, 0x10(%rsp)
    movq %rcx, 0x18(%rsp)
    movq %r8,  0x20(%rsp)
    movq %r9,  0x28(%rsp)

    movaps %xmm0, 0x30(%rsp)
    movaps %xmm1, 0x40(%rsp)
    movaps %xmm2, 0x50(%rsp)
    movaps %xmm3, 0x60(%rsp)
    movaps %xmm4, 0x70(%rsp)
    movaps %xmm5, 0x80(%rsp)
    movaps %xmm6, 0x90(%rsp)
    movaps %xmm7, 0xa0(%rsp)

    movq 0x00(%rsp), %rdi
    movq 0x08(%rsp), %rsi
    call sf_lookup_imp

    movq 0x00(%rsp), %rdi
    movq 0x08(%rsp), %rsi
    movq 0x10(%rsp), %rdx
    movq 0x18(%rsp), %rcx
    movq 0x20(%rsp), %r8
    movq 0x28(%rsp), %r9

    movaps 0x30(%rsp), %xmm0
    movaps 0x40(%rsp), %xmm1
    movaps 0x50(%rsp), %xmm2
    movaps 0x60(%rsp), %xmm3
    movaps 0x70(%rsp), %xmm4
    movaps 0x80(%rsp), %xmm5
    movaps 0x90(%rsp), %xmm6
    movaps 0xa0(%rsp), %xmm7

    addq $0xb8, %rsp
    jmp *%rax

.Lnil_return:
    xorl %eax, %eax
    pxor %xmm0, %xmm0
    ret

.size objc_msgSend, .-objc_msgSend
