; inputs:       rdx=segment:bcd,rsi=page physical root
; outputs:      rdx=segment:bcd(NOPE)
; clobbers:     rax,rcx,rdx,rdi,rsi
iommu.enable_device:



intel_iommu.enable_device:
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



amd_iommu.enable_device:
        ; enable paging and only paging
        mov     rdi, amd_iommu.device_table
        shl     edx, 5  ; 32-byte entries
        add     rdi, rdx
        mov     rax, AMD_IOMMU.DTE.0.IW + AMD_IOMMU.DTE.0.IR + AMD_IOMMU.DTE.0.MODE.L4 + AMD_IOMMU.DTE.0.TV + AMD_IOMMU.DTE.0.V
        or      rsi, rax
        mov     [rdi +  0], rsi
        xor     eax, eax
        mov     [rdi +  8], rax
        mov     [rdi + 16], rax
        mov     [rdi + 24], rax
        ; flush the DTE
        ; QEMU *always* "caches" the DTE, even if a device was never used before.
        mov     rdi, iommu.command_buf     
        mov     rax, [iommu.amd.command_tail]
        add     rdi, rax
        add     rax, 16
        and     rax, 4095
        ; TODO INVALIDATE_IOMMU_ALL should work ...
        ;   "The INVALIDATE_IOMMU_ALL command instructs the IOMMU to invalidate
        ;   all cached information for interrupt remapping and address translation
        ;   for guest and nested translations, including cached portions of the
        ;   Device Table, [...]"
        ; ... but it doesn't, as QEMU never reloads any DTEs.
        ; This is likely a bug in QEMU.
        ;
        ; INVALIDATE_DEVTAB_ENTRY does immediately reload the corresponding DTE
        ; however.
        ;mov     rcx, AMD_IOMMU.CMD.INVALIDATE_IOMMU_ALL shl 60
        mov     rcx, AMD_IOMMU.CMD.INVALIDATE_DEVTAB_ENTRY shl 60
        shr     edx, 5
        or      rcx, rdx
        mov     qword [rdi + 0], rcx
        xor     edx, edx
        mov     qword [rdi + 8], rdx
        mov     [iommu.amd.command_tail], rax
        ; FIXME don't busyloop
@@:     pause
        cmp     [iommu.amd.command_tail], rax
        jne     @b
        ret
