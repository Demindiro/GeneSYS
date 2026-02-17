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
	f 8, map_pcie_config
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

syscall.map_pcie_config:
	mov r15, 0 ; FIXME aaaaaa
	test rdi, rdi
	js   syscall.__panic
	test rdi, not (-1 shl 28)
	jnz  syscall.__panic
	mov  rcx, cr3
	irp x,3,2,1 {
		and  rcx, not 511
		mov  rax, rcx
		and  rcx,      (-1 shl 21)
		and  rax, not ((-1 shl 21) + 0xfff)
		or   rcx, PAGE.P + PAGE.RW + PAGE.PS
		mov  [paging.pd.temp], rcx
		if x < 3
			invlpg [temp.base]
		end if
		if x > 1
			lea  rdx, [temp.base + rax]
			mov  rax, rdi
			shr  rax, (9 * x) + 12
			and  rax, 511
			mov  rcx, [rdx + 8*rax]
			test rcx, PAGE.P
			jnz   @f
			call .alloc
	@@:		
		end if
	}
	mov rdi, temp.base + 0x11000
	mov ecx, 256
	lea r14, [bootinfo.pcie]
	mov rax, [bootinfo.pcie]
	or  rax, PAGE.P + PAGE.RW + PAGE.PS
@@:	stosq
	add rax, 1 shl 21
	loop @b
	hlt
	xor  eax, eax
	mov  [paging.pd.temp], rax
	invlpg [temp.base]
	hlt
	mov eax, -1
	mov edx, PCIE.MAX_ROOTS
	ret
.alloc:
	; FIXME no hardcode! hardcode very bad!
	mov rcx, [paging.pd.temp]
	and rcx, not 0xfff
	add rcx, 0x10000
	add rcx, r15
	add r15, 0x1000
	or  rcx, PAGE.P + PAGE.RW
	mov [rdx + 8*rax], rcx
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
