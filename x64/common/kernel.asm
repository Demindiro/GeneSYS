; == kernel memory layout ==
; 0xffffffffc0000000 - 0xffffffffc0200000 : code  (RX)
;   0xffffffffc01fffe0 - 0xffffffffc0200000 : boot info
; 0xffffffffc0200000 - 0xffffffffc0e00000 : guard (unmapped)
; 0xffffffffc0e00000 - 0xffffffffc1000000 : data  (RW)
;
; Two entire pages of
;
; Motivation: we want to minimize pointer chasing as kernel code/data
; is likely to be cold.
; Using 2M for both code and pages reduces the amount of TLB fetches to at most 2
; while reducing page fetches from 4 to 3.
; It does waste up to 4M of code, but that is negligible even for commonly "mini" VPSes:
; -  256M / 4M = 1.56%
; -  512M / 4M = 0.78%
; - 1024M / 4M = 0.39%
; Physical desktop/server 64-bit machines can reasonably be expected to have at least 1G of memory.
;
; A gap is added between code and data to help catch erroneous memory operations,
; but both PD entries are in the same cache line.


header:
.magic: db "GeneSYS", 0
.exec: dd exec.end - exec
.data: dd dat.end  - dat
.idt:  dw idt.end - idt - 1
       dq idt
.gdtr: dw gdt.end - gdt - 1
       dq gdt
times 28 db 0
assert $ = 64

;; structure passed by the bootloader
BOOTINFO.sizeof = 32

use64

org 0xffffffffc0000000
virtual at ($$ + (1 shl 21) - BOOTINFO.sizeof)
	bootinfo:
	; physical base address of the kernel code + data.
	; it is exactly 4M, with first 2M for code and last 2M for data.
	; it *must* be aligned on a 2M boundary.
	.phys_base: dq ?
	; the end (excl) virtual address of free data, starting from the head.
	; data past this point has been allocated by the bootloader and should
	; be used with care, as it includes page tables.
	; i.e.:
	;
	; |        code         |          gap          |         data        |
	;                                               |   free   |   used   |
	;                                                          ^~~~
	.data_free: dq ?
	; the start (incl) address of the map with regular usable memory
	;
	; note that this *includes* the memory used by the kernel.
	; to avoid incidents, always check `phys_base` before using memory
	; defined in this map.
	;
	; the memory map should be in the code region to keep it immutable
	; and keep more of the data region free.
	.memmap.start: dq ?
	; the end (excl) address of the map with regular usable memory
	.memmap.end: dq ?
end virtual
exec:
	mov edx, COM1.IOBASE
	call comx.init
@@:	mov rsi, rsp
	mov ecx, 1
	call comx.read
	mov rdi, rsp
	mov ebx, ecx
	mov ecx, 1
	sub ecx, ebx
	call comx.write
	jmp @b

@@:	hlt
	jmp @b

include "../common/idt.asm"
include "../common/gdt.asm"
include "../common/comx.asm"
include "../common/crc32c.asm"
exec.end:


org 0xffffffffc0e00000
dat:
dat.end:
