MSR.STAR   = 0xc0000081
MSR.LSTAR  = 0xc0000082
MSR.CSTAR  = 0xc0000083
MSR.SFMASK = 0xc0000084

SYSCALL.SYSCONF:
.EXC_DIVISION    =  0
.EXC_OVERFLOW    =  8
.EXC_INVALID_OP  = 16
.EXC_PAGE_FAULT  = 24
.EXC_FPU         = 32
.EXC_MACHINE     = 40
.INTERRUPT       = 48
.STACK           = 56

virtual at 0
	SYSCONF.stack_frame:
		.rip:    dq ?
		.rax:    dq ?
		.rdx:    dq ?
		.rdi:    dq ?
end virtual

syscall.init:
	mov ecx, MSR.STAR
	xor eax, eax
	mov edx, 0x00130008 ; kernel CS = 0x8, kernel SS = 0x10, user CS = 0x20, user SS = 0x18
	wrmsr
	mov ecx, MSR.LSTAR
	mov eax, syscall.entry64 and 0xffffffff
	mov edx, syscall.entry64 shr 32
	wrmsr
	mov ecx, MSR.CSTAR
	wrmsr
	mov ecx, MSR.SFMASK
	mov eax, 1 shl 9 ; IF
	xor edx, edx
	wrmsr
	ret

; note that system calls are non-reentrant,
; i.e. interrupts are never enabled.
;
; the sole exception to this rule is syscall.halt,
; which does enable interrupts but never returns here,
; instead using iretq to return to user space directly.
syscall.entry64:
	mov [_stack.end - 8], rsp
	mov rsp, _stack.end - 8
	irp x,rcx,rbx,rdi,rsi { push x }

	dec eax
	cmp eax, SYSCALL.MAX_SYSID
	ja .bad_id
	call qword [syscall.table + rax*8]

	irp x,rsi,rdi,rbx,rcx,rsp { pop x }
	sysretq

.bad_id:
@@:	hlt
	jmp @b

x = 0
macro f id, routine {
	x = x + 1
	assert x = id
	dq syscall.#routine
}
syscall.table:
	f 1, log
	f 2, halt
	f 3, identify
	f 4, set_configuration_space
	f 5, eoi
	f 6, read_debug_message
	f 7, send_debug_message
	f 8, pci_get_info
	f 9, pci_disable_device
	f 10, pci_enable_device
	f 11, pci_map_bar
SYSCALL.MAX_SYSID = x
purge f, x

syscall.log:
	push rdx
	mov rcx, rdx
	call syslog.push
	pop rdx
	ret

syscall.halt:
	; clear stack frame and reconstruct ISR arguments
	mov rsp, _stack.end
	push GDT.USER_SS
	sub rsp, 8  ; rsp is already set up properly
	push r11
	push GDT.USER_CS
	push rcx
	isr_pushall
	sti
	hlt
	cli
	isr_popall
	iretq

syscall.identify:
	mov rax, "GeneSYS"
	mov rdx, 0x20260130
	ret

syscall.set_configuration_space:
	; ensure the OS doesn't attempt to corrupt kernel space
	; simply forbidding negative half is sufficient
	test rsi, rsi
	js syscall.__panic  ; TODO
	mov [libos.sysconf_base], rsi
	ret

syscall.eoi:
	cmp edx, LIBOS.INTR.DEBUG
	je .enable_debug
	ud2
	ret
.enable_debug:
	and byte [libos.flags], not (1 shl LIBOS.FLAGS.INTR_DEBUG_PENDING)
	ret

syscall.read_debug_message:
	ud2
	ret
syscall.send_debug_message:
	ud2
	ret

syscall.pci_get_info:
	cmp     edx, 1 shl 16
	jae     .err
        mov     rdi, pcie_mmcfg
        shl     edx, 12
        add     rdi, rdx
        mov     eax , [rdi + PCI.MMCFG.id   ]
        mov     edx , [rdi + PCI.MMCFG.class]
if 0
        mov     r8d , [rdi + PCI.MMCFG.bar0 ]
        mov     r9d , [rdi + PCI.MMCFG.bar1 ]
        mov     r10d, [rdi + PCI.MMCFG.bar2 ]
        mov     r11d, [rdi + PCI.MMCFG.bar3 ]
        mov     r12d, [rdi + PCI.MMCFG.bar4 ]
        mov     r13d, [rdi + PCI.MMCFG.bar5 ]
end if
        ret
.err:	mov     eax, -1
	ret

syscall.pci_disable_device:
	ud2
	ret
syscall.pci_enable_device:
	ud2
	ret

syscall.pci_map_bar:
        ; ensure segment is valid
	cmp     edx, 1 shl 16
	jae     .err
        mov     rdi, pcie_mmcfg
        shl     edx, 12
        add     rdi, rdx
        ; ensure device is present
        mov     eax, [rdi + PCI.MMCFG.id]
        cmp     eax, -1
        je      .err
        ; disable MMIO and legacy I/O access as we'll modify the BARs temporarily
        and     dword [rdi + PCI.MMCFG.cmd], not (PCI.MMCFG.CMD.MMIO + PCI.MMCFG.CMD.LEGACY_IO)
        mov     ecx, -1
        ; I'd use irp if it would actually expand bar#n...
        macro f reg, bar {
                mov     eax, [rdi + PCI.MMCFG.#bar]
                mov     [rdi + PCI.MMCFG.#bar], ecx
                mov     reg, dword [rdi + PCI.MMCFG.#bar]
                mov     [rdi + PCI.MMCFG.#bar], eax
        }
        f r8d , bar0
        f r9d , bar1
        f r10d, bar2
        f r12d, bar3
        f r13d, bar4
        f r14d, bar5
        purge f
        ; re-enable MMIO access
        or      dword [rdi + PCI.MMCFG.cmd],     PCI.MMCFG.CMD.MMIO + PCI.MMCFG.CMD.LEGACY_IO
        ; fold 64-bit BARs and zero out legacy I/O BARs
        macro f a,b {
                mov     rax, a
                mov     rcx, b
                call    .fold_bars
                mov     a, rax
                mov     b, rcx
        }
        f r8 ,r9
        f r9 ,r10
        f r10,r12
        f r12,r13
        f r13,r14
        purge f
        ret
.err:   mov     eax, -1
        xor     edx, edx
	ret
; determine MMIO BAR sizes
; - ignore legacy I/O and all-zero BARs
; - account for 64-bit BARs
; - immediately fail if type is unrecognized
;
; inputs:   eax=current BAR, ecx=next BAR
; outputs:  rax=BAR size, ecx=next BAR (may be zeroed)
; clobbers: rdx
syscall.pci_map_bar.fold_bars:
.err = syscall.pci_map_bar.err
        ;test    eax, eax   ; redundant with MMIO_32=0 test below
        ;jz      .skip
        test    eax, 1     ; check for legacy I/O first, which is just a single bit
        jnz     .legio
        mov     edx, eax
        and     edx, PCI.MMCFG.BAR.TYPE.MMIO.MASK
        cmp     edx, PCI.MMCFG.BAR.TYPE.MMIO_64
        je      .comb
        cmp     edx, PCI.MMCFG.BAR.TYPE.MMIO_32
        jne     .err       ; unrecognized BAR type
        tzcnt   eax, eax
        ret
.legio: xor     eax, eax   ; ignore legacy I/O
        ret
.comb:  shl     rcx, 32    ; combine with next BAR
        or      rax, rcx
        xor     ecx, ecx
        and     rax, -16   ; for good measure, mask the type as we don't need it here
        tzcnt   rax, rax
        ret

syscall.__panic:
@@:	hlt
	jmp @b

; inputs: none
; outputs: rsi=sysconf base
sysconf.push_frame:
	mov rsi, [libos.sysconf_base]
	mov rdi, [rsi + SYSCALL.SYSCONF.STACK]
	sub rdi, 32
	mov rax, [isr.rip]
	mov rcx, [isr.rax]
	mov rdx, [isr.rdx]
	mov rbx, [isr.rdi]
	mov [rsi + SYSCALL.SYSCONF.STACK], rdi
	mov [rdi + SYSCONF.stack_frame.rip], rax
	mov [rdi + SYSCONF.stack_frame.rax], rcx
	mov [rdi + SYSCONF.stack_frame.rdx], rdx
	mov [rdi + SYSCONF.stack_frame.rdi], rbx
	ret
