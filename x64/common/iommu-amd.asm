amd_iommu.init:
	mov  rsi, pcie_mmcfg
	lea  rbx, [rsi + (1 shl 28)]
@@:	mov  eax, [rsi + PCI.MMCFG.class]
	shr  eax, 8
	cmp  eax, 0x080600
	je   .found_amd_iommu
	add  rsi, 1 shl 12
	cmp  rsi, rbx
	jne  @b
	jmp panic.no_iommu

.found_amd_iommu:
	push    rsi
	mov     rsi, trace.found_amd_iommu
	call    syslog.push_minimsg
	pop     rsi
	mov     eax, [rsi + PCI.MMCFG.cap_ptr]
	movzx   eax, al
@@:	test    eax, eax
	jz      panic.amd_iommu_missing_cap
	mov     edx, [rsi + rax]
	cmp     dl, 0xf
	je      .found_amd_iommu.cap
	movzx   eax, dh
	jmp     @b

.found_amd_iommu.cap:
	shr     edx, 16
	cmp     dl, 1011b  ; 48882-PUB—Rev 3.10—Feb 2025
	je      .amd_iommu_supported
	cmp     dl, 0011b ; ... whatever QEMU is
	jne     panic.amd_iommu_bad_version

.amd_iommu_supported:
	add     rsi, rax
	mov     [amd_iommu.pcie_mmcfg.cap], rsi
	mov     eax, [rsi + 8]
	mov     edx, [rsi + 4]
	shr     rax, 32
	or      rax, rdx
	or      edx, 1
	mov     [rsi + 4], edx
	and     rax, not 0xfff
	or      rax, PAGE.P + PAGE.RW
	mov     ecx, 4  ; TODO check for 16K or 512K
	mov     rdi, paging.pt_mmio.iommu
@@:	stosq
	add     rax, 1 shl 12
	loop    @b
	; enable memory space access
	mov     rsi, [amd_iommu.pcie_mmcfg.cap]
	and     rsi, not 0xfff
	mov     dword [rsi + 4], 2

.amd_iommu_reset:
	; TODO is there a proper reset option? Is it even necessary?
	xor     eax, eax
	;mov     [iommu.amd.control     ], rax

.amd_iommu_init:
	call    _init.alloc_2m
	or      rax, PAGE.P + PAGE.PS + PAGE.RW + PAGE.G
	mov     [paging.pd_misc.amd_iommu.device_table], rax
	or      rax, 0x1ff  ; maximum size (2MiB / 4KiB - 1 = 511)
	mov     qword [iommu.amd.device_table], rax
	mov     rax, (1 shl 21) + (iommu.command_buf - dat) + (8 shl 56)
	add     rax, [bootinfo.phys_base]
	mov     [iommu.amd.command_ring], rax
	add     rax, iommu.event_buf - iommu.command_buf
	mov     [iommu.amd.event_ring  ], rax
	mov     rdi, amd_iommu.device_table
	mov     ecx, (1 shl 21) / 8
	xor     eax, eax
	rep stosq

        ; force all transactions to go through the IOMMU by default
        ; TODO we should also issue INVALIDATE_DEVTAB
        mov     rdi, amd_iommu.device_table
        mov     rsi, amd_iommu.device_table + (1 shl 21)
@@:     mov     byte [rdi], AMD_IOMMU.DTE.0.V
        add     rdi, 32
        cmp     rdi, rsi
        jne     @b

.amd_iommu_enable:
	mov     [iommu.amd.control], AMD_IOMMU.CONTROL.IOMMU_EN + AMD_IOMMU.CONTROL.EVENT_LOG_EN + AMD_IOMMU.CONTROL.CMD_BUF_EN

.amd_iommu_test:
	; do a test to check if the IOMMU responds in an expected manner
	mov     rax, AMD_IOMMU.CMD.COMPLETION_WAIT shl 60
	mov     [iommu.command_buf + 0], rax
	xor     eax, eax
	mov     [iommu.command_buf + 8], rax
	mov     [iommu.amd.command_tail], 16 * 1
	mov     rdi, iommu.command_buf
	; TODO we ought to use a timer
	; use a very low amount of cycles for now
	mov     ecx, 1000
@@:	cmp     [iommu.amd.command_head], 16 * 1
	je      @f
	pause
	loop    @b
	jmp     panic.amd_iommu_no_response
@@:



; inputs:       rdx=segment:bcd,rsi=page physical root
; outputs:      rdx=segment:bcd(NOPE)
; clobbers:     rax,rcx,rdx,rdi,rsi
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
