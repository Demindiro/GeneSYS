macro ifeq x, y, target {
	cmp x, y
	je target
}
macro ifne x, y, target {
	cmp x, y
	jne target
}

macro log.ok msg {
	push rsi
	lea rsi, [msg]
	call printmsg.ok
	pop rsi
}

macro panic {
	cli
	hlt
}


org 0x9000
use16
disable_pic:
    mov al, 0xff
    out 0xa1, al
    out 0x21, al
identity_map:
.clear:
	mov di, 0x1000
	mov cx, (0x7000 - 0x1000) / 2
	xor eax, eax ; intentionally zero upper for later use
	rep stosw
	; hugepages in the 0 to 4MiB range are always split into 4KiB pages
	; see SDM 13.11.9 Large Page Size Considerations
	;
	; it supposedly has a performance penalty, but whatever :)
	; it just needs to work
.tree:
	mov word [0x1000], 0x2000 or 7 ; P, W, S
	mov word [0x2000], 0x3000 or 7 ; P, W, S
	mov word [0x2008], 0x4000 or 7 ; P, W, S
	mov word [0x2010], 0x5000 or 7 ; P, W, S
	mov word [0x2018], 0x6000 or 7 ; P, W, S
	; FIXME is this proper? might cross MTRR boundaries above 4MiB...
.leaves_2m:
	mov eax, 0 or 0x87 ; page size, present, write, user
	mov di, 0x3000
@@:	stosd
	add eax, (1 shl 21)
	add di, 4
	cmp di, 0x7000
	jne @b

enter_long_mode:
	mov eax, 0x1000
	mov cr3, eax
	mov eax, 010100000b
	mov cr4, eax
	mov ecx, 0xc0000080
	rdmsr
	or ax, 0x101
	wrmsr
	mov ebx, cr0
	or ebx,0x80000001
	mov cr0, ebx
	lgdt [gdtr]
	mov ax, 0x10
	mov ss, ax
	mov ds, ax
	mov es, ax
	mov fs, ax
	mov gs, ax
	jmp 0x8:main

use64
main:
	mov [alloc.map.base], rdi
	mov [gsboot.base], rsi

	call alloc.init
	call page.init
	call syscall.init
	mov rcx, 0x0000400000000000
	add rcx, [rcx + 48]
	xor r11, r11
	sysretq
	hlt


panicmsg:
    mov ah, 4
    call printmsg
    panic

printmsg.warn:
	mov ah, 6
	jmp printmsg
printmsg.ok:
	mov ah, 2
	jmp printmsg
printmsg.info:
	mov ah, 7
	jmp printmsg
printmsg:
	push rcx
	movzx ecx, byte [rsi]
	inc esi
_print:
	push rdi
	push rdx
	mov edx, 160
	push rax
@@:	xor eax, eax
	lock cmpxchg [console.lock], dl
	jne @b
	pop rax
	sub edx, ecx
	test ecx, ecx
	jz .e
	movzx edi, byte [console.row]
	imul edi, 160
	add edi, 0xb8000
.l:	lodsb
	stosw
	loop .l
.e:	inc byte [console.row]
	mov ecx, edx
	xor eax, eax
	rep stosw
	mov byte [console.lock], 0
	pop rdx
	pop rdi
	pop rcx
	ret


macro msg name, s {
	local end
	msg_#name: db end - $ - 1, s
	end:
}

include "kernel/gdt.asm"
include "kernel/alloc.asm"
include "kernel/paging.asm"
include "kernel/syscall.asm"

console.lock: db 0
console.row: db 0

gsboot.base: dq 0
