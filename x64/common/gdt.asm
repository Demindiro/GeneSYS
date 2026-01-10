GDT.KERNEL_CS = 0x08
GDT.KERNEL_SS = 0x10
GDT.USER_SS   = 0x18
GDT.USER_CS   = 0x20

gdt:
	dq 0x0000000000000000
	dq 0x00af9b000000ffff ; 0x08, A, RW, S, E, DPL=0, P, L, G
	dq 0x00af93000000ffff ; 0x10, A, RW, S, DPL=0, P, L, G
	dq 0x00aff3000000ffff ; 0x18, A, RW, S, DPL=3, P, L, G
	dq 0x00affb000000ffff ; 0x20, A, RW, S, E, DPL=3, P, L, G
.end:

gdtr:
	dw gdt.end - gdt - 1
	dq gdt
