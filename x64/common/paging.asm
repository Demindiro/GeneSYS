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
	ud2

; inputs:   rdi=virtual address, rsi=physical address + proper bits set
; outputs:  eax=0 if ok, eax<0 if err
paging.map_2m:
	push rbp
	mov  rbp, [paging.virt_to_phys]
	mov  rax, cr3
	mov  ecx, 9*4
.walk:
	mov  rdx, rdi
	and  rax, not 0xfff
	shr  rdx, cl
	sub  rax, rbp
	and  rdx, 511 shl 3
	add  rdx, rax
	mov  rax, [rdx]
	test rax, rax
	jz   .alloc
.n:	sub  ecx, 9
	cmp  ecx, 18
	jne  .walk
.leaf:
	sub  rax, rbp
	shr  rdi, cl
	and  rax, not 0xfff
	and  rdi, 511 shl 3
	mov  [rax + rdi], rsi
	pop  rbp
	ret
.alloc:
	mov  rax, [paging.free_table]
	test rax, rax
	jz   .fail
	mov  rbx, [rax]
	mov  [paging.free_table], rbx
	xor  ebx, ebx
	mov  [rax], rbx
	add  rax, rbp
	or   rax, PAGE.P + PAGE.RW + PAGE.US
	mov  [rdx], rax
	jmp  .n
.fail:
	pop  rbp
	ud2
	mov  eax, -1
	ret
