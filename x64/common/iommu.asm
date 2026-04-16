; inputs:       rdx=segment:bcd,rsi=page physical root
; outputs:      rdx=segment:bcd(NOPE)
; clobbers:     rax,rcx,rdx,rdi,rsi
iommu.enable_device:
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
