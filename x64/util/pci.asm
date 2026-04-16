virtual at 0
	PCI.MMCFG::
		.id              dd ?
		.cmd             dd ?
		.class           dd ?
		dd ?  ; BIST etc
		irp x,0,1,2,3,4,5 { .bar#x  dd ? }
		.cardbus         dd ?
		.sub_id          dd ?
		.expansion_rom   dd ?
		.cap_ptr         dd ?
		dd ?  ; reserved
		dd ?  ; interrupt line etc
end virtual

PCI.MMCFG.CMD::
        .LEGACY_IO  = 1 shl 0
        .MMIO       = 1 shl 1
        .BUS_MASTER = 1 shl 2

PCI.MMCFG.BAR::
        .TYPE.LEGACY_IO = 1
        .TYPE.MMIO.MASK = 7
        .TYPE.MMIO_32   = 0
        .TYPE.MMIO_64   = 4
