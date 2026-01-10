use64

org (-1 shl 21) - (2 shl 12)
page.kernel:
main:
	mov edx, COM1.IOBASE
	call comx.init
@@:	mov rsi, rsp
	mov ecx, 1
	call comx.read
	mov rdi, rsp
	mov ebx, ecx
	mov ecx, 1
	sub ecx, ebx
	call comx.write
	jmp @b

@@:	hlt
	jmp @b

include "../common/idt.asm"
include "../common/gdt.asm"
include "../common/comx.asm"
include "../common/crc32c.asm"
