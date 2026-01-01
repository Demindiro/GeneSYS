PAGE.P   = 1 shl  0
PAGE.RW  = 1 shl  1
PAGE.US  = 1 shl  2
PAGE.PWT = 1 shl  3
PAGE.PCD = 1 shl  4
PAGE.A   = 1 shl  5
PAGE.D   = 1 shl  6
PAGE.PS  = 1 shl  7
PAGE.PAT = 1 shl  7
PAGE.G   = 1 shl  8
PAGE.XD  = 1 shl 63

page.init:
page.init.user:
	xor eax, eax
	mov rdi, 1 shl 23
	mov ecx, 0x3000 / 8
	rep stosq
	sub rdi, 0x3000
	mov qword [rdi + 0x0000], ((1 shl 23) + 0x1000) or PAGE.US or PAGE.RW or PAGE.P ; pdpe
	mov qword [rdi + 0x1000], ((1 shl 23) + 0x2000) or PAGE.US or PAGE.RW or PAGE.P ; pde
	mov qword [rdi + 0x2000], page.test or PAGE.US or PAGE.RW or PAGE.P ; pte

	mov rax, cr3
	mov qword [rax + 1024], ((1 shl 23) + 0x0000) or PAGE.US or PAGE.RW or PAGE.P
	ret


align 0x1000
page.test:
	mov eax, 1
	syscall
	xor eax, eax
	syscall
	ud2
