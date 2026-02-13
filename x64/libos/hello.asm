use64

SYS.LOG      = 1
SYS.HALT     = 2
SYS.IDENTIFY = 3

macro trace msg {
	mov eax, SYS.LOG
	lea rsi, [msg]
	mov edx, msg#.end - msg
	syscall
}

start:
	trace msg_hello

.identify_kernel:
	mov eax, SYS.IDENTIFY
	syscall
	mov r8, "GeneSYS"
	cmp rax, r8
	jne err_bad_kernel_identification
	cmp rdx, 0x20260130
	jne err_bad_kernel_identification

	trace msg_identified

	jmp halt

err_bad_kernel_identification:
	trace err_bad_kernel_identification.msg
halt:
	mov eax, SYS.HALT
	syscall
	jmp halt

syslog:
	ret

msg_hello: db "Hello world!", 10
.end:
msg_identified: db "GeneSYS identified", 10
.end:

err_bad_kernel_identification.msg: db "error: kernel identification failed", 10
.end:
