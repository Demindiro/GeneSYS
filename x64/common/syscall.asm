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
	irp x,rdx,rsi,rdi,rcx { push x }

	mov ecx, edx
	mov rdx, COM1.IOBASE
	call comx.write

	irp x,rcx,rdi,rsi,rdx { pop x }
	mov rsp, [syscall.scratch]
	xor eax, eax
	sysretq
