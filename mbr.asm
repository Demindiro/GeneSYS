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
	mov esp, 0x1000

load_memory_map:
	log msg_e810
	; ... we'll assume it won't be more than 128 free entries or so
	; ... and also than E810 is definitely present
	xor ebx, ebx
	mov edx, 0x534d4150
	mov di, 0x7000
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

identity_map:
	log msg_identity_map
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
	mov word [0x1000], 0x2000 or 3 ; P, W
	mov word [0x2000], 0x3000 or 3 ; P, W
	mov word [0x2008], 0x4000 or 3 ; P, W
	mov word [0x2010], 0x5000 or 3 ; P, W
	mov word [0x2018], 0x6000 or 3 ; P, W
	; FIXME is this proper? might cross MTRR boundaries above 4MiB...
.leaves_2m:
	mov eax, 0 or 0x83 ; page size, present, write
	mov di, 0x3000
@@:	stosd
	add eax, (1 shl 21)
	add di, 4
	cmp di, 0x7000
	jne @b

enter_long_mode:
	log msg_enter_long_mode
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
    jmp 0x10:bootloader.base_address

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
msg msg_identity_map, "identity-mapping first 4GiB"
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

edd_packet:
.packet_size: dw 16
.sectors: dw bootloader.required_size / 512
.offset: dw 0x8000
.segment: dw 0xdead ; filled in at runtime
.lba: dq gpt.part1 shr 9


times (440-($-start)) db 0
mbr:
db "LMNG", 0, 0
dd 0x00020000, 0xffffffee, 1, 0xffffffff
times 3 dq 0, 0
db 0x55, 0xaa
assert $ - start = 512

org 512

macro gpt_header {
	db "EFI PART" ; header signature
	dd 0x00010000 ; header revision
	dd 92         ; header size
	dd 0          ; header CRC32 (FIXME)
	dd 0          ; reserved
	dq 1          ; header LBA
	dq gpt_alt    ; alternate header LBA
	dq 0x8000     ; first usable LBA
	dq 0xf000     ; last usable LBA
	db "Legacy Lemmings!" ; GUID
	dq 2          ; partition entry LBA
	dd 128        ; number of partitions
	dd 128        ; partition entry size
	dd 0          ; partition entries CRC32 (FIXME)
}

gpt: gpt_header

times (0x2000 - $) db 0
times (0x8000 - $) db 0

gpt.part1:
file "build/bootloader.bin"

times (bootloader.required_size - ($ - gpt.part1)) db 0
assert $ = 0x10000

gpt_alt: gpt_header
times ((0x1000 - $) and 0xfff) db 0

; must be at least this long to boot in QEMU
; what the fuck do I fucking know this makes no fucking sense
times (((1 shl 19) - $) - (1 shl 13) - (1 shl 9) + 1) db 0
