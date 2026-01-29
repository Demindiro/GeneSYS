use64

@@:	mov eax, 1
	lea rdi, [rip + s]
	mov ecx, s.end - s
	syscall
	jmp @b

s: db "Hello world!"
.end:
