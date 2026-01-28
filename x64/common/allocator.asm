; == Physical memory allocator + MMU ==
;
; The current allocator is only a small subset of what is described in Doc/arch/x64.
; Currently implemented is:
; - the bitmap between 1MiB-2MiB

include "../util/paging.asm"

allocator.init:
	; allocate 4K page
	mov rdx, [data_free]
	and rdx, not 0xfff
	sub rdx, 0x1000
	mov [data_free], rdx
	; populate bitmap in first half
	mov rdi, rdx
	mov ecx, 256
	mov eax, (1 shl 20) or PAGE.G or PAGE.A or PAGE.D or PAGE.RW or PAGE.P
@@:	stosq
	add eax, 0x1000
	loop @b
	; clear second half
	mov ecx, 256
	xor eax, eax
	rep stosq
	; virt -> phys
	add rdx, (1 shl 21) - dat
	add rdx, [bootinfo.phys_base]
	; insert 4K page
	; TODO avoid this pointer-chasing nonsense
	or rdx, PAGE.G or PAGE.A or PAGE.D or PAGE.RW or PAGE.P

	mov rax, cr3         ; PML4
	sub rax, [bootinfo.phys_base]
	and rax, not 0xfff
	add rax, dat - (1 shl 21)

	mov rax, [rax + 511*8] ; PDP
	sub rax, [bootinfo.phys_base]
	and rax, not 0xfff
	add rax, dat - (1 shl 21)

	mov rax, [rax + 511*8] ; PD
	sub rax, [bootinfo.phys_base]
	and rax, not 0xfff
	add rax, dat - (1 shl 21)

	mov [rax + 5*8], rdx

	; zero out bitmap
	mov ecx, (1 shl 20) / 8
	mov rdi, allocator.bitmap
	xor rax, rax
	rep stosq

	; populate bitmap
	mov rsi, [bootinfo.memmap.start]
	mov rbx, [bootinfo.memmap.end]
@@:	mov rcx, [rsi + 0]  ; start
	mov rdx, [rsi + 8]  ; end
	add rsi, 16
	; we work only in units of pages, so shift now to simplify later maths
	; simultaneously: round start up, end down
	; incidentally: 52 - 21 = 31, so we can work with 32-bit registers
	add rcx, (1 shl 21) - 1
	shr rcx, 21
	shr rdx, 21
	; if empty, skip
	cmp ecx, edx
	jae @b
	; two cases:
	; - we only need to fill a single qword
	; - we need to fill at least 2 qwords
	mov eax, ecx
	and eax, -64
	add eax, 64
	cmp eax, edx
	jb .bitmap_many_qword
.bitmap_one_qword:
	; |-----xxxxxx----|
	mov edi, ecx
	sub ecx, edx
	mov rax, -1
	shr rax, cl
	mov ecx, edi
	and ecx, 63
	shl rax, cl
	shr edi, 6
	or [allocator.bitmap + rdi*8], rax
	cmp rsi, rbx
	jne @b
	jmp .bitmap_end
.bitmap_many_qword:
	; |-----xxxxx|xxxxxxx...xxxxxxx|xxxxx-----|
	; |  prefix  |      fill       |  suffix  |
	; prefix
	mov edi, ecx
	shr edi, 6
	mov r8, rdi
	inc r8
	shl edi, 3
	and ecx, 63
	mov rax, -1
	shl rax, cl
	add rdi, allocator.bitmap
	or rax, [rdi]
	stosq
	; fill
	mov rax, -1
	mov ecx, edx
	shr ecx, 6
	sub rcx, r8
	rep stosq
	; suffix
	mov ecx, edx
	and ecx, 63
	mov eax, 1
	shl rax, cl
	dec rax
	stosq  ; the range map is sorted, so no need for a bitor here
	cmp rsi, rbx
	jne @b
.bitmap_end:


	hlt
	ret
