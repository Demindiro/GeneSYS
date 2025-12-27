include "config.inc"

org 0x7c00

;;;
;;; 16 bit area
;;;

macro log msg {
	mov si, msg
	call println
}

use16
start:
	mov ebp, 0x1000

load_memory_map:
	log msg_e810
	; ... we'll assume it won't be more than 128 free entries or so
	; ... and also than E810 is definitely present
	; ... and address 1024+256 actually exists and is unused regular RAM
	xor ebx, ebx
	mov edx, 0x534d4150
	mov di, 1024 + 256
.loop:
	mov eax, 0xe820
	mov ecx, 24
	int 0x15
	jc .end
	; skip non-free memory
	cmp byte [di + 16], 1
	jne @f
	; +16 because we don't care about the type
	add di, 16
@@:	test ebx, ebx
	jnz .loop
.end:

load_partition:
	log msg_partition
	mov si, edd_packet
	mov [edd_packet.segment], ds
	mov ah, 0x42
	mov dl, 0x80
	int 0x13

disable_pic:
	log msg_disable_pic
	cli
    mov al, 0xff
    out 0xa1, al
    out 0x21, al

identity_map_2mb:
	log msg_identity_map_2mb
	mov di, 0x1000
	mov dx, 3
.clear:
	mov si, di
	mov cx, 0x1000 / 2
	xor eax, eax ; intentionally zero upper for later use
	rep stosw
	lea ax, [di + 3] ; present, write
	mov [si], ax
	dec dx
	jnz .clear

	mov ax, 3
.leaves:
	stosd
	add eax, 0x1000
	add di, 4
	cmp eax, (1 shl 20) or 3
	jne .leaves

enter_long_mode:
	log msg_enter_long_mode
    mov eax, 0x1000
    mov cr3, eax
    mov eax, 010100000b
    mov cr4, eax
    mov ecx, 0xc0000080
    rdmsr
    or ax, 0x100
    wrmsr
    mov ebx, cr0
    or ebx,0x80000001
    mov cr0, ebx
    lgdt [gdtr]
    jmp 0x10:bootloader_base_address

purge log

print:
	xor cx, cx
	lodsb
	mov cl, al
@@:	lodsb
	mov ah, 0xe
	int 0x10
	loop @b
	ret
println:
	call print
	mov si, msg_nl
	jmp print


macro msg label, s {
	local end
	label: db end - $ - 1, s
	end:
}

msg_nl: db 2, 13, 10
msg msg_e810, "loading E810"
msg msg_partition, "loading first partition"
msg msg_disable_pic, "disabling PIC"
msg msg_identity_map_2mb, "identity-mapping first 2MiB"
msg msg_enter_long_mode, "entering long mode"
purge msg


gdt:
; I confess, I used ChatGPT for this
; just swapped the last two entries because lol syscall lol
dq 0x00000000000000000        ; 0x00 null
dq 0x000af92000000ffff        ; 0x08 64-bit data segment
dq 0x000af9a000000ffff        ; 0x10 64-bit code segment
.end:

gdtr:
dw gdt.end - gdt - 1
dd gdt

bootloader_base_address = 0x8000
bootloader_required_size = 0x10000 - 0x8000

edd_packet:
.packet_size: dw 16
.sectors: dw bootloader_required_size / 512
.offset: dw 0x8000
.segment: dw 0xdead ; filled in at runtime
.lba: dq partition.lba.3


times (440-($-start)) db 0
mbr:
db "LMNG"
db 0, 0
rept 4 i:0 {
	.partition.#i:
	if i = 3
		dd 1
	else
		dd 0
	end if
	dd 0, partition.lba.#i, partition.sectors.#i
}
db 0x55, 0xaa
assert $ - start = 512

org 512

times (0x1000 - 512) db 0

rept 4 i:0 {
	local base
	base: partition.#i
	times (512-$) and 0x1ff db 0
	partition.lba.#i = base shr 9
	partition.sectors.#i = ($ - base) shr 9
}
