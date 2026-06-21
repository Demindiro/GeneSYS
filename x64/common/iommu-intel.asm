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
