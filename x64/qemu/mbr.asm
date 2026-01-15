; designed for QEMU specifically but includes some provisions for real HW

; 0x500-0x600 should be free but avoid it just in case
org 0x600
use16
	; skip bpb because firmware may write to it
	jmp .relocate
	align 64
.relocate:
	xor ax, ax
	mov ds, ax
	mov es, ax
	mov ss, ax
	mov sp, 0x1000
	mov si, 0x7c00
	mov di, 0x600
	mov cx, 256
	rep movsw
	jmp 0:main

main:
.find:
	mov si, mbr.partitions
	mov cx, 4
@@:	test byte [si], MBR.BOOTABLE
	jnz .found
	add si, 16
	loop @b
	jmp err_noboot
.found:
	push si
	add si, 8
	mov di, edd_packet.lba
	xor ax, ax
	movsw
	movsw
	stosw
	stosw
	mov si, edd_packet
	mov ah, 0x42
	mov dl, 0x80
	int 0x13
	jc err_noread
	pop si   ; partition entry
	jmp 0:0x7c00


err_noread:
	mov si, msg_noread
	jmp panic
err_noboot:
	mov si, msg_noboot
panic:
	lodsb
	xor cx, cx
	mov cl, al
@@:	lodsb
	mov ah, 0xe
	int 0x10
	loop @b
.halt:
	cli
	hlt
	jmp .halt

msg_noboot: db .end - $ - 1, "No bootable partition found"
.end:
msg_noread: db .end - $ - 1, "Failed to read VBR"
.end:

edd_packet:
.packet_size: dw 16
.sectors: dw 1
.offset: dw 0x7c00
.segment: dw 0
.lba: dq 0

assert $ <= $$ + 440
times (440-($-$$)) db 0xcc

MBR.BOOTABLE = 1 shl 7
MBR.TYPE     = 0x79 ; bogus type

mbr:
	db "LMNG", 0, 0
.partitions:
	dd MBR.BOOTABLE, MBR.TYPE, part1 shr 9, (part1.end - part1) shr 9
	times 3 dd 0, 0, 0, 0
.magic:
	db 0x55, 0xaa
	assert $ - $$ = 512

org 512
; TODO avoid hardcoded path
part1: file "build/qemu/vbr.img"
times ((-$) and 0x1ff) db 0
.end:

; must be at least this long to boot in QEMU
; yes I'm annoyed
times ((1 shl 20) - $) db 0
