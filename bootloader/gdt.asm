gdt:
dq 0x0000000000000000
dq 0x00af93000000ffff ; A, RW, S, DPL=0, P, L, G
dq 0x00af9b000000ffff ; A, RW, E, S, DPL=0, P, L, G
dq 0x00aff3000000ffff ; A, RW, S, DPL=3, P, L, G
dq 0x00affb000000ffff ; A, RW, E, S, DPL=3, P, L, G
dq 0x00cffb000000ffff ; A, RW, E, S, DPL=3, P, G
dq 0x00cff3000000ffff ; A, RW, S, DPL=3, P, G
.end:
gdtr:
dw gdt.end - gdt - 1
dq gdt
