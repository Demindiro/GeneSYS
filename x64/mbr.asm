org 0x7c00

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
	mov di, 0x500
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
	; use -1 (negative) as end marker
	mov al, -1
	mov cx, 16
	rep stosb

load_partition:
	log msg_partition
	mov si, edd_packet
	mov [edd_packet.segment], ds
	mov ah, 0x42
	mov dl, 0x80
	int 0x13

	mov cx, 12 / 2
	mov si, 0x8000
	mov di, gsboot_magic
	rep cmpsw
	jnz err_not_gsboot

	cli
	mov eax, 1
	mov cr0, eax
	lgdt [gdtr]
	mov ax, 0x10
	mov ss, ax
	mov ds, ax
	mov es, ax
	mov fs, ax
	mov gs, ax
	jmp 0x8:main32

err_not_gsboot:
	log msg_err_not_gsboot
@@:	hlt
	jmp @b

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

use32
main32:
	mov edi, 0x500
	mov esi, 0x8000
	lea eax, [esi + 0x1000]
	jmp eax


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
msg msg_err_not_gsboot, "missing GeneSYS BOOT magic"
purge msg
gsboot_magic: db "GeneSYS BOOT"

gdt:
dq 0x0000000000000000
dq 0x00cf9b000000ffff ; 0x28, A, RW, S, E, DPL=0, P, G
dq 0x00cf93000000ffff ; 0x30, A, RW, S, DPL=0, P, G
.end:
gdtr:
dw gdt.end - gdt - 1
dq gdt

edd_packet:
.packet_size: dw 16
.sectors: dw 0x7000 / 512
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
file "build/root.gsboot"

gpt_alt: gpt_header
times ((-$) and 0xfff) db 0

; must be at least this long to boot in QEMU
; what the fuck do I fucking know this makes no fucking sense
times (((1 shl 19) - $) - (1 shl 13) - (1 shl 9) + 1) db 0
