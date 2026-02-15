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
	jmp exception_end

exception_invalid_op:
	trace err_badop
	jmp exception_end

interrupt:
	trace msg_interrupt
	jmp exception_end


exception_end:
	add qword [sysconf.stack], 32
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
msg_interrupt: db "Received interrupt", 10
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
.interrupt:      dq interrupt
.stack:          dq exc_stack.end

exc_stack:
rb ((-$) and 4095)
.end:
