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
	mov rdi, [gsboot.base]
	mov rdi, [rdi + 32]
	or rdi, PAGE.US or PAGE.RW or PAGE.P ; pte

	push rdi
	call alloc.page
	pop qword [rdi]
	or rdi, PAGE.US or PAGE.RW or PAGE.P ; pde

	push rdi
	call alloc.page
	pop qword [rdi]
	or rdi, PAGE.US or PAGE.RW or PAGE.P ; pdpe

	push rdi
	call alloc.page
	pop qword [rdi]
	or rdi, PAGE.US or PAGE.RW or PAGE.P ; pml4e

	mov rax, cr3
	mov qword [rax + 1024], rdi

	ret
