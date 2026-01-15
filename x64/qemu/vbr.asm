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

kernel = kernel_base
include "../common/kernel.inc"


PAGE.P   =  1 shl  0
PAGE.RW  =  1 shl  1
PAGE.US  =  1 shl  2
PAGE.PWT =  1 shl  3
PAGE.PCD =  1 shl  4
PAGE.A   =  1 shl  5
PAGE.D   =  1 shl  6
;PAGE.PAT =  1 shl  7   ; either 7 or 12...
PAGE.PS  =  1 shl  7
PAGE.G   =  1 shl  8
PAGE.XD  =  1 shl 63

CR0.PE = 1 shl  0
CR0.PG = 1 shl 31

CR4.PAE    =  1 shl  5
CR4.PGE    =  1 shl  7
CR4.PCIDE  =  1 shl 17

MSR.EFER = 0xc0000080
MSR.EFER.SCE = 1 shl 0
MSR.EFER.LME = 1 shl 8

org 0x7c00
use16
	; skip bpb
	jmp start
	align 32

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
	mov si, msg_noread
	jc panic
	inc dword [edd_packet.lba]

load_memory_map:
	; ... we'll assume it won't be more than 128 free entries or so
	; ... and also that E820 is definitely present
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

zero_kernel:
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

enter_long_mode:
	cli
	mov eax, kernel_pml4
	mov cr3, eax
	mov eax, CR4.PAE or CR4.PGE ; or CR4.PCIDE
	mov cr4, eax
	mov ecx, MSR.EFER
	rdmsr
	or eax, MSR.EFER.SCE or MSR.EFER.LME
	wrmsr
	mov ebx, cr0
	or ebx, CR0.PE or CR0.PG
	mov cr0, ebx
	lgdt [gdtr]
	mov ax, 0x10
	mov ss, ax
	mov ds, ax
	mov es, ax
	mov fs, ax
	mov gs, ax
	jmp 0x8:main64

; edi: destination
; ecx: sector count (max 127)
;
; reads first to 0x10000, then copies to edi,
; incrementing edi and edd_packet.lba by read amount.
read_kernel_part:
	push edi
	mov word [edd_packet.sectors], cx
	mov word [edd_packet.segment], 0x1000 ; 0x10 * 0x1000 = 0x10000 = 64KiB
	mov word [edd_packet.offset ], 0
	mov si, edd_packet
	mov ah, 0x42
	mov dl, 0x80
	int 0x13
	pop edi
	mov si, msg_noread
	jc panic
	add dword [edd_packet.lba], ecx
.copy:
	mov esi, 1 shl 16
	shl cx, 9 - 2
@@:	mov eax, [esi]
	add esi, 4
	mov [edi], eax
	add edi, 4
	loop @b
	ret

panic:
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


msg_noread: db .end - $ - 1, "Failed to read kernel"
.end:

edd_packet:
.packet_size: dw 16
.sectors: dw 1
.offset: dw main64
.segment: dw 0
.lba: dq 0

assert $ <= 0x7c00 + 510
times (510 - ($-$$)) db 0xcc
db 0x55, 0xaa
assert $ - $$ = 512

use64
main64:
.bootinfo:
	mov edi, kernel_bootinfo
	mov dword [rdi + BOOTINFO.phys_base], kernel_base
	;; TODO
	mov dword [rdi + BOOTINFO.data_free], 0
	mov dword [rdi + BOOTINFO.memmap.start], 0
	mov dword [rdi + BOOTINFO.memmap.end  ], 0
	;;
	jmp KERNEL.CODE.START

gdt:
	dq 0x0000000000000000
	dq 0x00af9b000000ffff ; 0x08, A, RW, S, E, DPL=0, P, L, G
	dq 0x00af93000000ffff ; 0x10, A, RW, S, DPL=0, P, L, G
.end:
gdtr:
	dw gdt.end - gdt - 1
	dq gdt

	times ((-$) and 0x1ff) db 0xcc

main64.end:
assert $ and 0x1ff = 0

org 0
file "build/qemu/kernel.bin"
KERNEL.SIZE = $
