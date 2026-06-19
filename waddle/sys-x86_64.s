.intel_syntax noprefix
.globl _start

_start:
	pop		rdi        # argc
	mov		rsi, rsp   # argv
	lea		rdx, [rsi + rdi*8 + 8] # environ
	and		rsp, -0x10 # align
	call	main
	mov		edi, eax   # exit status
	mov		eax, 60    # SYS_EXIT
	syscall
	ud2

.section .note.GNU-stack  # disable executable stack
