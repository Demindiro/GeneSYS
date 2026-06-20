PCIE.MAX_ROOTS = 4

KERNEL.CODE.START = 0xffffffffc0000000
KERNEL.CODE.END   = KERNEL.CODE.START + (1 shl 21)
KERNEL.DATA.START = KERNEL.CODE.START + (7 shl 21)
KERNEL.DATA.END   = KERNEL.DATA.START + (1 shl 21)

virtual at 0
	BOOTINFO:
		.phys_base:      dq ?
		.init_pagetable: dq ?
                .mem_pages.base         dq ?
                .mem_pages_4k.len       dd ?
                .mem_pages_2m.len       dd ?
                .mem_pages_1g.len       dd ?
                                        dd ?    ; padding
		.libos.start:    dq ?
		.libos.end:      dq ?
		; list of PCIe root bases
		.pcie: rb (PCIE.MAX_ROOTS * 16)
		.sizeof:
end virtual

virtual at 0
        PCIE_SEGMENT::
                .start_addr             dq ?
                .end_addr               dq ?
                .intel_iommu_base       dq ?
                                        dq ?  ; reserved/padding
                .sizeof:
                .FLAG_INTEL_VT_D = 1 shl 0
end virtual
