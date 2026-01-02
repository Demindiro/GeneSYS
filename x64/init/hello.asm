org 0
db "GeneSYS EXEC"
dw 0x8664, 0x0000
dq 0, 1, 0, 0
dq start

use64
start:
	mov eax, 1
	syscall
	mov eax, 2
	syscall
	mov rdi, 0xb8000
	mov word [rdi], 0xffff
	xor eax, eax
	syscall
	ud2
