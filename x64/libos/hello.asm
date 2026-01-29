use64

@@:	mov eax, 1
	lea rsi, [s]
	mov edx, s.end - s
	syscall
	jmp @b

s: db "Hello world!", 10
.end:
