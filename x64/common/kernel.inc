PCIE.MAX_ROOTS = 4

KERNEL.CODE.START = 0xffffffffc0000000
KERNEL.CODE.END   = KERNEL.CODE.START + (1 shl 21)
KERNEL.DATA.START = KERNEL.CODE.START + (7 shl 21)
KERNEL.DATA.END   = KERNEL.DATA.START + (1 shl 21)

macro decl_bootinfo name, loc {
virtual at loc
        name::
        ; physical base address of the kernel code + data.
        ; it is exactly 4M, with first 2M for code and last 2M for data.
        ; it *must* be aligned on a 2M boundary.
        .phys_base              dq ?
        ; the physical address of the initial page table.
        ;
        ; this table is immutable and can be used for "fast reboots".
        .init_pagetable         dq ?
        ; arrays with offsets in terms of pages
        ; i.e. PPN = page_size * x
        ; for 2M and larger this covers all possible physical addresses (max 2**52)
        ; for 4K pages this only goes up to 2**44, but this is unlikely to be an issue.
        ; starts with 4K pages, then 2M, finally 1G
        .mem_pages.base         dq ?
        .mem_pages_4k.len       dd ?
        .mem_pages_2m.len       dd ?
        .mem_pages_1g.len       dd ?
                                dd ?    ; padding
        ; the start (incl) address of the initial libos
        .libos.start            dq ?
        ; the end (excl) address of the initial libos
        .libos.end              dq ?
        ; list of PCIe root bases
        .pcie:        rb (PCIE.MAX_ROOTS * PCIE_SEGMENT.sizeof)
        .sizeof = $ - .phys_base
end virtual
}

virtual at 0
        PCIE_SEGMENT::
                .start_addr             dq ?
                .end_addr               dq ?
                .intel_iommu_base       dq ?
                                        dq ?  ; reserved/padding
                .sizeof:
                .FLAG_INTEL_VT_D = 1 shl 0
end virtual
