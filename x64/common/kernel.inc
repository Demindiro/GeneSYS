KERNEL.CODE.START = 0xffffffffc0000000
KERNEL.CODE.END   = KERNEL.CODE.START + (1 shl 21)
KERNEL.DATA.START = KERNEL.CODE.START + (7 shl 21)
KERNEL.DATA.END   = KERNEL.DATA.START + (1 shl 21)

virtual at 0
	BOOTINFO:
		.phys_base:      dq ?
		.init_pagetable: dq ?
		.memmap.start:   dq ?
		.memmap.end:     dq ?
		.libos.start:    dq ?
		.libos.end:      dq ?
		.sizeof:
end virtual
