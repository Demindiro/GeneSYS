virtual at 0
	PCI.MMCFG:
		.id:             dd ?
		.cmd:            dd ?
		.class:          dd ?
		dd ?  ; BIST etc
		irp x,0,1,2,3,4,5 { .bar#x: dd ? }
		.cardbus:        dd ?
		.sub_id:         dd ?
		.expansion_rom:  dd ?
		.cap_ptr:        dd ?
		dd ?  ; reserved
		dd ?  ; interrupt line etc
end virtual
