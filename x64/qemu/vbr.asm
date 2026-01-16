kernel_base = 1 shl 21  ; put kernel in range 2MiB to 6MiB
kernel_code = kernel_base + (0 shl 21)
kernel_data = kernel_base + (1 shl 21)
kernel_end  = kernel_base + (2 shl 21)

kernel_bootinfo = kernel_code + (1 shl 21) - BOOTINFO.sizeof

kernel_pd   = kernel_end - (1 shl 12)
kernel_pdp  = kernel_end - (2 shl 12)
kernel_pml4 = kernel_end - (3 shl 12)

idmap_pd  = 0x1000
idmap_pdp = 0x2000

e820_count = 0x6004
e820_base  = 0x6008

kernel = kernel_base
include "../common/kernel.inc"

include "../util/paging.asm"
include "../util/registers.asm"

org 0x7c00
use16
	; skip bpb
	jmp start
	align 64

start:
	mov esp, 0x1000
	; si points to active MBR partition
	; we only care about the LBA, ignore the rest
	mov eax, [si + 8]
	inc eax ; skip VBR, which would be us
	; load extra sector of bootcode
	mov dword [edd_packet.lba], eax
	mov si, edd_packet
	mov ah, 0x42
	mov dl, 0x80
	int 0x13
	jc err_noread
	inc dword [edd_packet.lba]

zero_lomem:
	; knowing the low mem is zero simplifies some things
	mov di, 0x1000
	mov cx, (0x4000 - 0x1000) / 2
	xor ax, ax
	rep stosw

load_memory_map:
	; ... we'll assume it won't be more than 128 free entries or so
	; ... and also that E820 is definitely present
	xor ebx, ebx
	mov edx, 0x534d4150
	mov di, e820_base
.loop:
	mov eax, 0xe820
	mov ecx, 24
	int 0x15
	jc .end
	add di, 24
	test ebx, ebx
	jnz .loop
.end:
	sub di, e820_base
	; divide by 24 (valid for [0;128])
	imul ax, di, (1 + ((1 shl 12) / 24))
	shr ax, 12
	mov word [e820_count + 0], ax
	mov word [e820_count + 2], 0

zero_kernel:
	call enter_unreal
	; zero out entire kernel code/data region
	mov ecx, 2 shl (21 - 2)
	mov edi, kernel_base
	xor eax, eax
@@:	mov [edi], eax
	add edi, 4
	dec ecx
	jnz @b

init_pagetable:
	; PD: 0 -> code, 7 -> data
	mov eax, kernel_code + PAGE.P + PAGE.PS + PAGE.G
	mov edx, kernel_data + PAGE.P + PAGE.PS + PAGE.G + PAGE.RW
	mov [kernel_pd + (8*0)], eax
	mov [kernel_pd + (8*7)], edx
	; PDP: 511
	mov eax, kernel_pd + PAGE.P + PAGE.RW
	mov [kernel_pdp + (511*8)], eax
	; PML4: 511
	mov eax, kernel_pdp + PAGE.P + PAGE.RW
	mov [kernel_pml4 + (511*8)], eax
	; set up identity mapping for first 6MiB
	; we can safely use a hugepage for 0-2M (see Intel manual)
	mov di, 0x1000
	mov cx, (0x4000 - 0x1000) / 2
	xor ax, ax
	rep stosw
	mov  word [idmap_pd +  0], (0 shl 21) + PAGE.P + PAGE.PS + PAGE.RW  ; PDE
	mov dword [idmap_pd +  8], (1 shl 21) + PAGE.P + PAGE.PS + PAGE.RW  ; PDE
	mov dword [idmap_pd + 16], (2 shl 21) + PAGE.P + PAGE.PS + PAGE.RW  ; PDE
	mov  word [idmap_pdp  ], idmap_pd  + PAGE.P + PAGE.RW  ; PDPE
	mov  word [kernel_pml4], idmap_pdp + PAGE.P + PAGE.RW  ; PML4E

load_kernel:
	mov edi, kernel_base
	; we can load the kernel in a single read if it remains under 128 sectors
	; (BIOS can only reliably read 127 sectors at once)
	; if it ever proves insufficient, do a loop of 127 sectors,
	; then a tail with however much remains.
	assert KERNEL.SIZE <= (127 shl 9)
	mov ecx, (KERNEL.SIZE + 0x1ff) shr 9
	call read_kernel_part

	jmp enter_long_mode

; edi: destination
; ecx: sector count (max 127)
;
; reads first to 0x10000, then copies to edi,
; incrementing edi and edd_packet.lba by read amount.
read_kernel_part:
	call exit_unreal
	push edi
	mov word [edd_packet.sectors], cx
	mov word [edd_packet.segment], 0x1000 ; 0x10 * 0x1000 = 0x10000 = 64KiB
	mov word [edd_packet.offset ], 0
	mov si, edd_packet
	mov ah, 0x42
	mov dl, 0x80
	int 0x13
	pop edi
	jc err_noread
	add dword [edd_packet.lba], ecx
.copy:
	call enter_unreal
	mov esi, 1 shl 16
	shl cx, 9 - 2
@@:	mov eax, [esi]
	add esi, 4
	mov [edi], eax
	add edi, 4
	loop @b
	ret

err_noread:
	mov si, msg_noread
panic:
	call exit_unreal
	lodsb
	xor cx, cx
	mov cl, al
@@:	lodsb
	mov ah, 0xe
	int 0x10
	loop @b
.halt:
	hlt
	jmp .halt

; enter protected mode, set 4G limits for ds and es
; then leave protected mode again
; TODO perhaps just stay in protected mode?
enter_unreal:
	cli
	lgdt [gdtr]
	; We hit an *emulator* bug here:
	;  1. (un)real mode (probably) runs under QEMU TCG regardless of KVM
	;  2. mov ds, ax uses a stale value under some circumstances
	; a "special" instruction inbetween appears to be a sufficient fix
	mov ax, 0x20
	mov ebx, cr0
	or bl, CR0.PE
	mov cr0, ebx
	; far jump appears unnecessary, but apparently it is UB
	; to do anything but do a far jump right after enabling protected mode,
	; so do the right thing.
	jmp 0x18:@f
@@:	use32
	;mov ax, 0x20  ; see above
	mov ds, ax
	mov es, ax
	and bl, not CR0.PE
	mov cr0, ebx
	jmp 0:@f
@@:	use16
	ret

; set ds and es to 0
; this is necessary to avoid confusing the BIOS
; run this before any BIOS interrupt
exit_unreal:
	xor ax, ax
	mov ds, ax
	mov es, ax
	ret


msg_noread: db .end - $ - 1, "Failed to read kernel"
.end:

edd_packet:
.packet_size: dw 16
.sectors: dw 1
.offset: dw bootloader
.segment: dw 0
.lba: dq 0

assert $ <= 0x7c00 + 510
times (510 - ($-$$)) db 0xcc
db 0x55, 0xaa
assert $ - $$ = 512

bootloader:

enter_long_mode:
	cli
	mov eax, kernel_pml4
	mov cr3, eax
	; we'll need SSE it for radixsort
	mov eax, (CR4.OSFXSR or CR4.OSXMMEXCPT) or CR4.PAE or CR4.PGE ; or CR4.PCIDE
	mov cr4, eax
	mov ecx, MSR.EFER
	rdmsr
	or eax, MSR.EFER.SCE or MSR.EFER.LME
	wrmsr
	mov ebx, cr0
	or ebx, CR0.MP or CR0.PE or CR0.PG
	and ebx, not CR0.EM
	mov cr0, ebx
	lgdt [gdtr]
	mov ax, 0x10
	mov ss, ax
	mov ds, ax
	mov es, ax
	mov fs, ax
	mov gs, ax
	jmp 0x8:main64

use64
main64:
.memmap:
	; copy free E820 entries
	mov edi, kernel_bootinfo
	mov esi, e820_count
	lodsd
	mov ecx, eax
.l:	cmp byte [rsi + 16], 1
	jne @f
	sub edi, 16
	lodsq
	mov [rdi], rax
	lodsq
	mov [rdi + 8], rax
	add esi, 8
	loop .l
@@:	add esi, 24
	loop .l
	mov esi, kernel_bootinfo
	call memmap.radixsort
	call memmap.merge

.bootinfo:
	mov ebx, kernel_bootinfo
	mov qword [rbx + BOOTINFO.phys_base], kernel_base
	mov qword [rbx + BOOTINFO.data_free], KERNEL.DATA.END - (3 shl 12)
	add rdi, KERNEL.CODE.START - kernel_code
	add rsi, KERNEL.CODE.START - kernel_code
	mov [rbx + BOOTINFO.memmap.start], rdi
	mov [rbx + BOOTINFO.memmap.end  ], rsi
	jmp KERNEL.CODE.START

	include "../util/memmap.asm"

gdt:
	dq 0x0000000000000000
	dq 0x00af9b000000ffff ; 0x08, A, RW, S, E, DPL=0, P, L, G
	dq 0x00af93000000ffff ; 0x10, A, RW, S,    DPL=0, P, L, G
	dq 0x008f9b000000ffff ; 0x18, A, RW, S, E, DPL=0, P, G   <--  for "unreal" mode
	dq 0x008f93000000ffff ; 0x20, A, RW, S,    DPL=0, P, G   <--  for "unreal" mode
.end:
gdtr:
	dw gdt.end - gdt - 1
	dq gdt

	times ((-$) and 0x1ff) db 0xcc

main64.end:
assert $ = $$ + 1024

org 0
file "build/qemu/kernel.bin"
KERNEL.SIZE = $
