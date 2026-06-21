include "../util/intel-iommu.asm"


IOMMU.PAGE.RW = 0


virtual at iommu
        intel_iommu.decl_mmio iommu.intel
end virtual


virtual at intel_iommu.translation_structures
        intel_iommu:
                .root_address_table     rq 2*256
                .context_table_0        rq 4*256
                .intr_remap_table       rq 2*256
                ; Notes
                ; - We don't support request-with-PASID (PASID in TLP)
                ; - We do need at least one directory entry for each device
                ; - 2^(x+7) => at least 128 entries.
                ;   Note that each leaf has exactly 64 entries, so at least 2 leaves
                .pasid_table_0          rq 8*64*2
                ; at least 2 tables
                .pasid_directory_0      rq 2
                .sizeof = $ - intel_iommu
        assert intel_iommu.sizeof <= (1 shl 21)
end virtual



; rsi: IOMMU registers base address
intel_iommu.init:
        ; map IOMMU registers
	mov     rdi, paging.pt_mmio.iommu
        or      rsi, PAGE.P + PAGE.RW + PAGE.G
	mov     [rdi], rsi
        ; check version (TODO actually check)
        mov     eax, [iommu.intel.version]
        ; allocate space for translation structures
	call    _init.alloc_2m
        push    rax     ; <0>
	or      rax, PAGE.P + PAGE.PS + PAGE.RW + PAGE.G
	mov     [paging.pd_misc.intel_iommu.translation_structures], rax
        ; zero out translation structures
        mov     ecx, (1 shl 21) / 8
        mov     rdi, intel_iommu.translation_structures
        xor     eax, eax
        rep stosq
        ; set root table in scalable mode
        pop     rax     ; <0>
        mov     rdx, rax
        or      rax, (1 shl 10)
        mov     [iommu.intel.root_table_addr], rax
        ; link context table for bus 0
        lea     rax, [rdx + (intel_iommu.context_table_0 - intel_iommu) + 1]
        mov     [intel_iommu.root_address_table + (8*0)], rax
        add     rax, 4096
        mov     [intel_iommu.root_address_table + (8*1)], rax
        ; link PASID tables
        lea     rax, [rdx + (intel_iommu.pasid_table_0 - intel_iommu) + 1]
        int3
        mov     [intel_iommu.pasid_directory_0 + (8*0)], rax
        add     rax, 4096
        mov     [intel_iommu.pasid_directory_0 + (8*1)], rax
        ; set interrupt remapping table
        mov     qword [iommu.intel.intr_remap_tbl_addr], intel_iommu.intr_remap_table
        ; reload root table and interrupt remapping table
        mov     dword [iommu.intel.global_command], (1 shl 30) + (1 shl 24)
@@:     pause
        mov     eax, [iommu.intel.global_status]
        not     eax     ; invert so set bits become clear
        test    eax, (1 shl 30) + (1 shl 24)
        jnz     @b      ; we want all bits _clear_
        ; enable translation of DMA and interrupts
        mov     dword [iommu.intel.global_command], (1 shl 31) + (1 shl 25)
@@:     pause
        mov     eax, [iommu.intel.global_status]
        not     eax     ; invert so set bits become clear
        test    eax, (1 shl 31) + (1 shl 25)
        jnz     @b      ; we want all bits _clear_
        ret



; inputs:       rdx=segment:bcd,rsi=page physical root
; outputs:      rdx=segment:bcd(NOPE)
; clobbers:     rax,rcx,rdx,rdi,rsi
iommu.enable_device:
        ; TODO bus other than 0
        test    dh, dh
        jnz     .fail_todo.non_zero_bus
        movzx   edx, dl
        ; set context table entry
        lea     rdi, [intel_iommu.context_table_0]
        shl     rdx, 5
        add     rdi, rdx
        mov     rdx, [iommu.intel.root_table_addr] ; TODO avoid MMIO read here
        and     rdx, not 0xfff
        mov     rax, intel_iommu.pasid_directory_0 - intel_iommu + 1
        add     rax, rdx
        mov     qword [rdi], rax
        ; set PASID table entry
        lea     rdi, [intel_iommu.pasid_table_0]
        ; ensure present bit is set last!
        mov     rax, cr3
        and     rax, not 0xfff
        mov     qword [rdi + 24], 0
        mov     qword [rdi + 16], rax
        ; FSPM = 4-level paging, DID = 1
        mov     qword [rdi +  8], (0 shl 2) + 1
        ; PGTT = first-stage only, AW = 48-bit, P = 1
        mov     qword [rdi +  0], (1 shl 6) + (2 shl 2) + 1
        ; flush context cache
        mov     rax, (1 shl 63) + (1 shl 61)
        mov     [iommu.intel.context_command], rax
        mov     rax, 1 shl 63
@@:     test    [iommu.intel.context_command], rax
        jnz     @b
        ret
.fail_todo.non_zero_bus:
        ud2
