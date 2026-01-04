org 0x7c00

gsboot_base = 1 shl 20

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
	call read_13h

	cmp dword [0x10000], "Gene"
	jne err_not_gsboot
	cmp dword [0x10004], "SYS "
	jne err_not_gsboot
	cmp dword [0x10008], "BOOT"
	jne err_not_gsboot

	mov  cl, [0x1000c]
	; TODO check if proper page size
	mov edx, [0x10010]
	add edx, [0x10014]
	add edx, [0x10018]
	sub cl, 9
	shl edx, cl

.all:
	mov esi, 0x10000
	mov edi, gsboot_base
	mov ecx, (512 / 4) * 127
@@:	mov eax, [esi]
	add esi, 4
	mov [edi], eax
	add edi, 4
	loop @b
	add edi, 127 * 512
	sub edx, 127
	js .done
	add dword [edd_packet.lba], 127
	push edi
	push edx
	call read_13h
	pop edx
	pop edi
	jmp .all
.done:

adjust_e820:
	; TODO do a proper scan
	mov dword [0x500 + 1*16], edi

enter_protected_mode:
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

read_13h:
	mov si, edd_packet
	mov ah, 0x42
	mov dl, 0x80
	int 0x13
	ret

use32
main32:
	mov edi, 0x500
	mov esi, gsboot_base
	lea eax, [esi + 28]
	jmp eax


macro msg label, s {
	local end
	label: db end - $ - 1, s
	end:
}

msg_nl: db 2, 13, 10
msg msg_e810, "loading E810"
msg msg_partition, "loading first partition"
msg msg_err_not_gsboot, "missing GeneSYS BOOT magic"
purge msg

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
.sectors: dw 127
.offset: dw 0
.segment: dw 0x1000 ; 0x10 * 0x1000 = 0x10000 = 64KiB
.lba: dq gpt.part1 shr 9

assert $ <= 0x7c00 + 440
times (440-($-start)) db 0xcc
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
;times (((1 shl 19) - $) - (1 shl 13) - (1 shl 9) + 1) db 0
times ((1 shl 19) - $) db 0
