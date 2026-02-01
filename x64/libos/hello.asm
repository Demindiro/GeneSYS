use64

SYS.LOG      = 1
SYS.HALT     = 2
SYS.IDENTIFY = 3

	mov eax, SYS.LOG
	lea rsi, [s]
	mov edx, s.end - s
	syscall

	mov eax, SYS.IDENTIFY
	syscall

	lea rsi, [scratch]
	mov [rsi], rax
	mov edx, 9
	mov eax, SYS.LOG
	syscall

@@:	mov eax, SYS.HALT
	syscall
	jmp @b

s: db "Hello world!", 10
.end:

scratch: dq 0
db 10
