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
	lea rax, [syscall.entry64]
	mov rdx, rax
	shr rdx, 32
	wrmsr
	mov ecx, MSR.CSTAR
	wrmsr
	mov ecx, MSR.SFMASK
	mov eax, 1 shl 9 ; IF
	xor edx, edx
	wrmsr
	ret

syscall.entry64:
syscall.entry32:
	mov r8, rax
	mov r9, rcx
	mov r10, r11
	lea rsi, [msg_syscall]
	call printmsg.ok
	mov rcx, r9
	mov r11, r10
	test r8, r8
	jnz @f
	hlt
@@:	sysretq


msg syscall, "System call!"
