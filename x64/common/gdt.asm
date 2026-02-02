GDT.KERNEL_CS = 0x08 or 0
GDT.KERNEL_SS = 0x10 or 0
GDT.USER_SS   = 0x18 or 3
GDT.USER_CS   = 0x20 or 3
GDT.TSS       = 0x28 or 3

align 8
init_gdt:
	dq 0x0000000000000000
	dq 0x00af9b000000ffff ; 0x08, A, RW, S, E, DPL=0, P, L, G
	dq 0x00af93000000ffff ; 0x10, A, RW, S, DPL=0, P, L, G
	dq 0x00aff3000000ffff ; 0x18, A, RW, S, DPL=3, P, L, G
	dq 0x00affb000000ffff ; 0x20, A, RW, S, E, DPL=3, P, L, G
.tss:
	dw tss.end - tss - 1, tss and 0xffff
	db (tss shr 16) and 0xff, 0x89, 0, (tss shr 24) and 0xff
	dq tss shr 32
.end:
