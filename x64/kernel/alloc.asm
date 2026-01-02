alloc.map.base: dq 0

alloc.init:
	; assume QEMU/VM always has a sorted map which includes the very lowest addresses
	; immediately exclude this region as we need it for our own purposes.
	; we may want to adjust this at some point.
	;
	; do perform a few fixes however:
	; - immediately reserve all memory below 64K as we and the page table are located there
	; - round start/end addresses to 4K boundary
	mov rdi, [alloc.map.base]
	mov qword [rdi], 1 shl 16
@@:	mov rax, [rdi]
	test rax, rax
	js @f
	add rax, 0xfff ; round up
	and rax, -0x1000
	stosq
	and qword [rdi], -0x1000 ; round down
	add rdi, 8
	jmp @b
@@:	ret

; allocate a single 4K page.
; always zeros the page
; halts if no pages remaining.
;
; rdi: base of page
alloc.page:
	mov rsi, [alloc.map.base]
@@:	lodsq
	test rax, rax
	js .oom
	mov rdx, rax
	lodsq
	cmp rdx, rax
	je @b
	mov rdi, rdx
	xor eax, eax
	mov ecx, 0x1000 / 8
	rep stosq
	mov [rsi - 16], rdi
	mov rdi, rdx
	ret
.oom:
	lea rsi, [msg_oom]
	jmp panicmsg

msg oom, "out of memory"
