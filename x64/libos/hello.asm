use64

org 0x3fe00000

SYS.LOG      = 1
SYS.HALT     = 2
SYS.IDENTIFY = 3
SYS.SET_CONFIG_SPACE = 4
SYS.EOI      = 5
SYS.PCI_GET_INFO        = 8
SYS.PCI_DISABLE_DEVICE  = 9
SYS.PCI_ENABLE_DEVICE   = 10
SYS.PCI_MAP_BAR         = 11

DEV.EDU.STATUS.FACT_FIN   = 1 shl 0
DEV.EDU.STATUS.FACT_INTR  = 1 shl 7
DEV.EDU.DMA.INTERNAL_ADDR = 0x40000
DEV.EDU.DMA.START         = 1 shl 0
DEV.EDU.DMA.DIR           = 1 shl 1
DEV.EDU.DMA.INTR          = 1 shl 2

virtual at 0
        dev.edu::
                .id             dd ?
                .check          dd ?
                .fact           dd ?
                rb 0x20 - $
                .status         dd ?
                .intr.status    dd ?
                rb 0x60 - $
                .intr.raise     dd ?
                .intr.ack       dd ?
                rb 0x80 - $
                .dma.src        dq ?
                .dma.dst        dq ?
                .dma.len        dq ?
                .dma.cmd        dd ?
end virtual

INTR.TIMER = 1
INTR.DEBUG = 31

PCIE.BASE = 1 shl 40

macro syslog {
	mov eax, SYS.LOG
	syscall
}
macro trace msg {
	lea rsi, [msg]
	mov edx, msg#.end - msg
        syslog
}

start:
        mov     esp, stck.end
	trace msg_hello

.identify_kernel:
	mov eax, SYS.IDENTIFY
	syscall
	mov r8, "GeneSYS"
	cmp rax, r8
	jne err_bad_kernel_identification
	cmp rdx, 0x20260130
	jne err_bad_kernel_identification

	trace msg_identified

	mov eax, SYS.SET_CONFIG_SPACE
	lea rsi, [sysconf]
	syscall

        ; find edu device
        mov     r15, -1
@@:     inc     r15
        cmp     r15, 1 shl 16
        je      panic.no_edu_dev
        mov     rdx, r15
	mov     eax, SYS.PCI_GET_INFO
        syscall
        cmp     eax, 0x11e8_1234
        jne     @b

        ; log ID and segment
        mov     rdi, buf
        push    rax
        mov     edx, eax
        mov     ecx, 4
        call    fmt.num_to_hex_fixed
        pop     rdx
        mov     al, ':'
        stosb
        shr     edx, 16
        mov     ecx, 4
        call    fmt.num_to_hex_fixed
        mov     dword [rdi], " @ "
        add     rdi, 3
        mov     rdx, r15
        shr     edx, 8
        mov     ecx, 2
        call    fmt.num_to_hex_fixed
        mov     al, ':'
        stosb
        mov     rdx, r15
        shr     edx, 3
        and     edx, 31
        mov     ecx, 2
        call    fmt.num_to_hex_fixed
        mov     al, '.'
        stosb
        mov     rax, r15
        and     eax, 7
        mov     al, [fmt.hex_table + rax]
        stosb
        mov     al, 10
        stosb
        mov     rsi, buf
        mov     edx, edi
        sub     edx, esi
        syslog

        ; map edu device MMIO
        mov     eax, SYS.PCI_MAP_BAR
        mov     rdx, r15
        mov     rdi, pci_dev_bars
        mov     rsi, pci_dev_bars + (1 shl 30)
        syscall
        ; mask out log2(size)
        mov     rdi, r8
        and     rdi, -128
        ; test bitwise NOT
        mov     dword [rdi + dev.edu.check], not 0xdead1337
        cmp     dword [rdi + dev.edu.check],     0xdead1337
        jne     panic.edu_dev_bad_check
        ; test factorial
        mov     dword [rdi + dev.edu.fact], 7
@@:     test    dword [rdi + dev.edu.status], DEV.EDU.STATUS.FACT_FIN
        jnz     @b
        cmp     dword [rdi + dev.edu.fact], 5040
        jne     panic.edu_dev_bad_factorial

        ; enable edu device "bus mastering" / RAM access
        mov     eax, SYS.PCI_ENABLE_DEVICE
        mov     rdx, r15
        syscall

        ; test DMA
        mov     rax, "Behold!"
        mov     [buf], rax
        mov     qword [rdi + dev.edu.dma.src], buf
        mov     qword [rdi + dev.edu.dma.dst], 0x40000
        mov     qword [rdi + dev.edu.dma.len], 8
        mov     dword [rdi + dev.edu.dma.cmd], DEV.EDU.DMA.START
        mov ecx, 1 shl 24
        @@: loop @b
@@:     test    dword [rdi + dev.edu.dma.cmd], DEV.EDU.DMA.START
        jnz     @b
        mov     qword [buf], 0
        mov     qword [rdi + dev.edu.dma.src], 0x40000
        mov     qword [rdi + dev.edu.dma.dst], buf
        mov     qword [rdi + dev.edu.dma.len], 8
        mov     dword [rdi + dev.edu.dma.cmd], DEV.EDU.DMA.START + DEV.EDU.DMA.DIR
        mov ecx, 1 shl 24
        @@: loop @b
@@:     test    dword [rdi + dev.edu.dma.cmd], DEV.EDU.DMA.START
        jnz     @b
        cmp     [buf], rax
        jne     panic.edu_dev_bad_dma

        trace   msg_edu_dev_ok

	ud2



exception_division:
	trace err_div
	jmp exception_end

exception_invalid_op:
	trace err_badop
	jmp exception_end

interrupt:
	mov r15, rax
	cmp eax, INTR.DEBUG
	je interrupt_debug_message
	trace msg_interrupt
	jmp interrupt_end

interrupt_debug_message:
	trace msg_interrupt_debug_message
	jmp interrupt_end


interrupt_end:
	add qword [sysconf.stack], 32
	mov rdx, r15
	mov eax, SYS.EOI
	syscall
	jmp halt

exception_end:
	add qword [sysconf.stack], 32
	jmp halt


err_bad_kernel_identification:
	trace err_bad_kernel_identification.msg

halt:
	mov eax, SYS.HALT
	syscall
	jmp halt


; inputs:       rdi=destination,rdx=number,ecx=digits
; outputs:      rdi=destination end
; clobbers:     eax, ecx, rsi
fmt.num_to_hex_fixed:
        jrcxz   .end
        lea     rsi, [rdi + rcx]
@@:     mov     eax, edx
        and     eax, 15
        mov     al, [fmt.hex_table + rax]
        shr     edx, 4
        mov     [rdi + rcx - 1], al
        loop    @b
        mov     rdi, rsi
.end:   ret


panic.no_edu_dev:
        trace   msg_no_edu_dev
        jmp     halt
panic.edu_dev_bad_check:
        trace   msg_edu_dev_bad_check
        jmp     halt
panic.edu_dev_bad_factorial:
        trace   msg_edu_dev_bad_factorial
        jmp     halt
panic.edu_dev_bad_dma:
        trace   msg_edu_dev_bad_dma
        jmp     halt


msg_hello: db "Hello world!", 10
.end:
msg_identified: db "GeneSYS identified", 10
.end:
msg_interrupt: db "Received unknown interrupt", 10
.end:
msg_interrupt_debug_message: db "Received debug message", 10
.end:
msg_no_edu_dev: db "No edu device found (1234:11e3). Please add -device edu to the QEMU command line.", 10
.end:
msg_edu_dev_bad_check: db "edu check gave wrong result", 10
.end:
msg_edu_dev_bad_factorial: db "edu factorial gave wrong result", 10
.end:
msg_edu_dev_bad_dma: db "edu DMA failed", 10
.end:
msg_edu_dev_ok: db "edu works OK!", 10
.end:

err_div:   db "error: divide by zero"
.end:
err_badop: db "error: bad opcode exception"
.end:

err_bad_kernel_identification.msg: db "error: kernel identification failed", 10
.end:

fmt.hex_table  db "0123456789abcdef"

rb ((-$) and 63)
sysconf:
.exc_division:   dq exception_division
.exc_overflow:   dq 0
.exc_invalid_op: dq exception_invalid_op
.exc_page_fault: dq 0
.exc_fpu:        dq 0
.exc_machine:    dq 0
.interrupt:      dq interrupt
.stack:          dq exc_stack.end

exc_stack:
rb ((-$) and 4095)
.end:

stck:   rb 96
.end:
buf:    rb 4000
.end:

org (1 shl 40)
pci_dev_bars:
