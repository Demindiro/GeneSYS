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
