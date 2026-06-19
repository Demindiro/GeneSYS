macro _paging.mask_pte_addr reg {
        ; clear [11:0] and sign-extend [64:52]
        ; don't forget to clear the high bits... (XD, AMD_IOMMU.PTE.{IR,IW})
        shl     reg, 64 - 52
        sar     reg, 64 - 52 + 12
        shl     reg, 12
}

paging.init:
	; first table is guaranteed to be valid
	mov  rax, [paging.free_table]
	mov  rcx, [rax]
	mov  [paging.free_table], rcx
	xor  ecx, ecx
	mov  [rax], rcx
	mov  rsi, paging.pml4
	mov  rdi, rax
	mov  ecx, 512
	rep  movsq
	add  rax, [paging.virt_to_phys]
	mov  cr3, rax
	ret

; inputs:   rdi=virtual address, rsi=physical address + proper bits set
paging.map_4k:
        mov     ebx, 9
        jmp     _paging.map_page

; inputs:   rdi=virtual address, rsi=physical address + proper bits set
; outputs:  eax=0 if ok, eax<0 if err
; preserves: rdi, rsi
; clobbers:  rcx, rdx, rbx
paging.map_2m:
        mov     ebx, 18
        ; fallthrough

; inputs:   rdi=virtual address, rsi=physical address + proper bits set
;           rbx=9 for 4K pages, 18 for 2M pages, 27 for 1G pages.
;           rcx=9*4 for 2M pages, 9*5 for 4K pages
; outputs:  eax=0 if ok, eax<0 if err
; preserves: rdi, rsi
; clobbers:  rcx, rdx, rbx
_paging.map_page:
	push rbp
	mov  rbp, [paging.virt_to_phys]
	mov  rax, cr3
	mov  ecx, 9*4
.walk:
	mov  rdx, rdi
        _paging.mask_pte_addr   rax
	shr  rdx, cl
	sub  rax, rbp
	and  rdx, 511 shl 3
	add  rdx, rax
	mov  rax, [rdx]
	test rax, rax
	jz   .alloc
.n:	sub  ecx, 9
	cmp  ecx, ebx
	jne  .walk
.leaf:
	mov  rdx, rdi
        ;int3
        ;hlt
	sub  rax, rbp
	shr  rdx, cl
        _paging.mask_pte_addr   rax
	and  rdx, 511 shl 3
	mov  [rax + rdx], rsi
	pop  rbp
	ret
.alloc:
        ; allocate page
	mov  rax, [paging.free_table]
	test rax, rax
	jz   .fail
        push    rbx
	mov  rbx, [rax]
	mov  [paging.free_table], rbx
	xor  ebx, ebx
	mov  [rax], rbx
        ; translate virt->phys
	add  rax, rbp
        ; set bits
        mov     rbx, PAGE.P + PAGE.RW + PAGE.US + AMD_IOMMU.PTE.IR + AMD_IOMMU.PTE.IW
        or      rax, rbx
        ; set NextLevel bits for IOMMU
        mov     ebx, ecx
        imul    ebx, ((1 shl 24) / 9)
        shr     ebx, 24
        shl     ebx, AMD_IOMMU.PTE.NEXTLVL_SHIFT
        or      rax, rbx
        ; put entry
	mov  [rdx], rax
        pop     rbx
	jmp  .n
.fail:
	pop  rbp
	ud2
	mov  eax, -1
	ret

; Map a range of pages using the most optimal page size.
; All pages must have the same cache type.
; If any mapping fails, the range is cleared entirely.
; Any existing mappings in the range are unconditionally cleared.
;
; inputs:    rdi=virtual start address, rsi=physical start address, r11=virtual end address
; outputs:   eax=0 if ok, eax<0 if err, rdi=virtual end address
; clobbers:  rcx, rdx, rbx
paging.map_range:
        ; TODO "optimal page size"
        or      rsi, PAGE.P + PAGE.RW + PAGE.US
        cmp     rdi, r11
        jne     paging.map_range_4k
        ret

; Map a range of 4K pages.
; The range *must not* be empty!
;
; inputs:    rdi=virtual start address, rsi=physical start address + proper bits set, r11=virtual end address
; outputs:   eax=0 if ok, eax<0 if err, rdi=virtual end address
; preserves: rdi, rsi
paging.map_range_4k:
@@:     call    paging.map_4k
        add     rdi, 1 shl 12
        add     rsi, 1 shl 12
        cmp     rdi, r11
        jne     @b
        ret

; Map a range of 2M pages.
; The range *must not* be empty!
;
; inputs:    rdi=virtual start address, rsi=physical start address + proper bits set, r11=virtual end address
; outputs:   eax=0 if ok, eax<0 if err, rdi=virtual end address
; preserves: rdi, rsi
paging.map_range_2m:
@@:     call    paging.map_2m
        add     rdi, 1 shl 21
        add     rsi, 1 shl 21
        cmp     rdi, r11
        jne     @b
        ret
