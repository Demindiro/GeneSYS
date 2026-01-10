use64

align 4096
org (-1 shl 21) - (1 shl 12)
page.boot:
boot:
	cli

if 0
	lgdt [gdtr]
	hlt
	mov ax, GDT.KERNEL_SS
	mov ds, ax
	mov es, ax
	mov ss, ax
	mov fs, ax
	mov gs, ax
	push @f
	push GDT.KERNEL_CS
	retfq
@@:	lidt [idtr]
end if

	;jmp main

include "../common/kernel.asm"
