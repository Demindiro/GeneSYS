use64

org 0x3fe00000

SYS.LOG      = 1
SYS.HALT     = 2
SYS.IDENTIFY = 3
SYS.SET_CONFIG_SPACE = 4

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

	mov eax, SYS.SET_CONFIG_SPACE
	lea rsi, [sysconf]
	syscall

	ud2

	jmp halt



exception_division:
	trace err_div
	jmp halt

exception_invalid_op:
	trace err_badop
	jmp halt



err_bad_kernel_identification:
	trace err_bad_kernel_identification.msg
halt:
	mov eax, SYS.HALT
	syscall
	jmp halt

msg_hello: db "Hello world!", 10
.end:
msg_identified: db "GeneSYS identified", 10
.end:

err_div:   db "error: divide by zero"
.end:
err_badop: db "error: bad opcode exception"
.end:

err_bad_kernel_identification.msg: db "error: kernel identification failed", 10
.end:

rb ((-$) and 63)
sysconf:
.exc_division:   dq exception_division
.exc_overflow:   dq 0
.exc_invalid_op: dq exception_invalid_op
.exc_page_fault: dq 0
.exc_fpu:        dq 0
.exc_machine:    dq 0
dq 0  ; reserved
.irq: dq 0
.flags: dq 0
.reg_rip:    dq 0
.reg_rflags: dq 0
.reg_rax:    dq 0
dq 0, 0, 0, 0  ; reserved
