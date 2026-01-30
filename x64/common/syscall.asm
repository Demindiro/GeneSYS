MSR.STAR   = 0xc0000081
MSR.LSTAR  = 0xc0000082
MSR.CSTAR  = 0xc0000083
MSR.SFMASK = 0xc0000084

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

syscall.entry64:
	mov [syscall.scratch], rsp
	mov rsp, _stack.end
	irp x,rcx,rbx,rsi,rdi { push x }

	dec eax
	cmp eax, SYSCALL.MAX_SYSID
	ja .bad_id
	call qword [syscall.table + rax*8]

	irp x,rdi,rsi,rbx,rcx { pop x }
	mov rsp, [syscall.scratch]
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
SYSCALL.MAX_SYSID = x
purge f, x

syscall.log:
	push rdx
	push rsi
	mov ecx, edx
	mov rdx, COM1.IOBASE
	call comx.write
	pop rax
	pop rdx
	sub rax, rsi
	ret

syscall.halt:
	hlt
	ret

syscall.identify:
	mov rax, "GeneSYS"
	mov rdx, 0x20260130
	ret
