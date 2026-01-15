; rdi: range start (incl)
; rsi: range end   (excl)
;
; Each element is [start, end). Only start is considered.
;
; The algorithm is in-place radix sort using a single bit as radix.
; This isn't very efficient but it is very simple.
;
; It uses at most 16*40 = 640 bytes on the stack.
memmap.radixsort:
	xor ebx, ebx
	bts rbx, 51  ; x86 supports at most 52 physical bits

.iter:
	cmp rdi, rsi
	je .r
	mov r10, rdi
	; 1. count zero bits
	xor ecx, ecx
@@:	xor edx, edx
	test [rdi], rbx
	setz dl
	add rdi, 16
	add ecx, edx
	cmp rdi, rsi
	jne @b
	; 2. swap elements with one bit to high partition
	mov rdi, r10
	shl ecx, 4
	add rcx, rdi
	push rcx         ; mid
@@:	xor edx, edx
	test [rdi], rbx
	jz .n
	xor edx, 16
	movaps xmm0, [rdi]
	movaps xmm1, [rcx]
	movaps [rcx], xmm0
	movaps [rdi], xmm1
.n:	add rcx, rdx
	xor edx, 16
	add rdi, rdx
	cmp rcx, rsi
	jne @b
	mov rdi, r10
	; recursively sort partitions
	pop  rcx
	cmp rbx, 1 shl 12  ; bits 0-11 are guaranteed to be zero
	jl .r
	shr rbx, 1
	push rsi
	mov  rsi, rcx
	call .iter
	pop  rcx
	push rdi
	mov  rdi, rsi
	mov  rsi, rcx
	call .iter
	pop rdi
	shl rbx, 1
.r:	ret

; Join contiguous regions.
;
; rdi: range start (incl) => new base
; rsi: range end   (excl)
memmap.merge:
	push rsi
	lea rbx, [rsi - 32]
	sub rsi, 16
@@:	mov rax, [rsi]
	cmp rax, [rbx + 8]
	ja .n
	mov rax, [rbx]
	mov [rsi], rax
	jmp .c
.n:	sub rsi, 16
	movaps xmm0, [rbx]
	movaps [rsi], xmm0
.c:	sub rbx, 16
	cmp rbx, rdi
	jne @b
	mov rdi, rsi
	pop rsi
	ret
