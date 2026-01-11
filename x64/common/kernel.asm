; == kernel memory layout ==
; 0xffffffffc0000000 - 0xffffffffc0200000 : code  (RX)
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

use64

org 0xffffffffc0000000
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
