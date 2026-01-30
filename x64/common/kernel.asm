; == kernel memory layout ==
; 0: 0xffffffffc0000000 - 0xffffffffc0200000 : code  (RX)
;      0xffffffffc01fffe0 - 0xffffffffc0200000 : boot info
; 1: 0xffffffffc0200000 - 0xffffffffc0400000 : guard (unmapped)
; 2: 0xffffffffc0400000 - 0xffffffffc0600000 : guard (unmapped)
; 3: 0xffffffffc0600000 - 0xffffffffc0800000 : temp page (unmapped/RW)
; 4: 0xffffffffc0800000 - 0xffffffffc0a00000 : guard (unmapped)
; 5: 0xffffffffc0a00000 - 0xffffffffc0b00000 : allocator bitmap
; 6: 0xffffffffc0c00000 - 0xffffffffc0e00000 : guard (unmapped)
; 7: 0xffffffffc0e00000 - 0xffffffffc1000000 : data  (RW)
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

include "../util/registers.asm"

;; structure passed by the bootloader
BOOTINFO.sizeof = 48

temp.base        = 0xffffffffc0600000
allocator.bitmap = 0xffffffffc0a00000

init_libos.base  = (1 shl 30) - (1 shl 21)

paging.pml4      = dat.end - 0x1000
paging.pdp       = dat.end - 0x2000
paging.pd        = dat.end - 0x3000
paging.pt_bitmap = dat.end - 0x4000
paging.pml4.pdp     = paging.pml4 + 8*511
paging.pdp.pd       = paging.pdp  + 8*511
paging.pd.code      = paging.pd + 8*0
paging.pd.temp      = paging.pd + 8*3
paging.pd.pt_bitmap = paging.pd + 8*5
paging.pd.data      = paging.pd + 8*7

irp x,pml4,pdp,pd,pt_bitmap { paging_phys.#x = (2 shl 21) + (paging.#x - dat.end) }

MSR.IA32_EFER = 0xc0000080
IA32_EFER.SCE = 1 shl  0
IA32_EFER.LME = 1 shl  8
IA32_EFER.NXE = 1 shl 11

use64

org 0xffffffffc0000000
virtual at (exec.end - BOOTINFO.sizeof)
	bootinfo:
	; physical base address of the kernel code + data.
	; it is exactly 4M, with first 2M for code and last 2M for data.
	; it *must* be aligned on a 2M boundary.
	.phys_base: dq ?
	; the physical address of the initial page table.
	;
	; this table is immutable and can be used for "fast reboots".
	.init_pagetable: dq ?
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
	; the start (incl) address of the initial libos
	.libos.start: dq ?
	; the end (excl) address of the initial libos
	.libos.end:   dq ?
end virtual
exec:
	lgdt [gdtr]
	mov ax, GDT.KERNEL_SS
	mov ss, ax
	mov rsp, _stack.end
	mov ds, ax
	mov es, ax
	mov fs, ax
	mov gs, ax
	lea rax, [@f]
	push GDT.KERNEL_CS
	push rax
	retfq
@@:	lidt [idtr]

	; load initial page table and ensure all global mappings are flushed.
	mov rax, cr4
	and rax, not CR4.PGE
	mov cr4, rax
	mov rax, [bootinfo.init_pagetable]
	mov cr3, rax

	; clear data region
	mov ecx, (dat.end - dat) / 8
	mov rdi, dat
	xor eax, eax
	rep stosq

	; construct new page table
	mov rbx, [bootinfo.phys_base]
	; PD
	lea rax, [rbx + (0 shl 21) + PAGE.A + PAGE.D + PAGE.PS + PAGE.G + PAGE.P]
	mov [paging.pd.code], rax
	lea rax, [rbx + (1 shl 21) + PAGE.A + PAGE.D + PAGE.PS + PAGE.RW + PAGE.G + PAGE.P]
	mov [paging.pd.data], rax
	lea rax, [rbx + paging_phys.pt_bitmap + PAGE.A + PAGE.D + PAGE.RW + PAGE.P]
	mov [paging.pd.pt_bitmap], rax
	; PDP
	lea rax, [rbx + paging_phys.pd  + PAGE.A + PAGE.D + PAGE.RW + PAGE.P]
	mov [paging.pdp.pd], rax
	; PML4
	lea rax, [rbx + paging_phys.pdp + PAGE.A + PAGE.D + PAGE.RW + PAGE.P]
	mov [paging.pml4.pdp], rax
	; load new page table with global enabled
	mov rax, cr4
	or  rax, CR4.PGE
	mov cr4, rax
	add rbx, paging_phys.pml4
	mov cr3, rbx

	; enable syscall instruction
	mov ecx, MSR.IA32_EFER
	mov eax, IA32_EFER.SCE or IA32_EFER.LME
	xor edx, edx
	wrmsr

	call allocator.init
	call syscall.init
	mov qword [syslog.head], 0

.load_libos:
	; allocate and initialize page table
	call allocator.alloc_2m
	mov r15, rax
	or rax, PAGE.PS or PAGE.RW or PAGE.P
	mov [paging.pd.temp], rax
	; zero out entire page
	mov ecx, (1 shl 21) / 8
	mov rdi, temp.base
	xor eax, eax
	rep stosq
	; copy kernel PML4
	; TODO more hardcoding please :)
	mov rsi, cr3
	sub rsi, [bootinfo.phys_base]
	add rsi, dat - (1 shl 21)
	add rsi, 2048
	mov rdi, temp.base + 2048
	mov ecx, 256
	rep movsq
	; PDP
	lea rax, [r15 + 0x1000 + (PAGE.US or PAGE.RW or PAGE.P)]
	mov [temp.base + 0x0000], rax
	; PD
	lea rax, [r15 + 0x2000 + (PAGE.US or PAGE.RW or PAGE.P)]
	mov [temp.base + 0x1000], rax
	; page table
	lea rax, [r15 + (PAGE.PS or PAGE.US or PAGE.P)]
	mov [temp.base + 0x3000 - 8*8], rax
	; OS code/data
	call allocator.alloc_2m
	or rax, PAGE.PS or PAGE.US or PAGE.RW or PAGE.P
	mov [temp.base + 0x3000 - 1*8], rax
	; done setting up page tables
	mov qword [paging.pd.temp], 0
	invlpg [temp.base]
	mov cr3, r15
	; copy OS code
	mov rsi, [bootinfo.libos.start]
	mov ecx, [bootinfo.libos.end  ]
	mov rdi, init_libos.base
	sub ecx, esi
	shr ecx, 3
	rep movsq
	mov ecx, esi
	not ecx
	and ecx, (1 shl 21) - 1
	shr ecx, 3
	xor eax, eax
	rep stosq
.start_libos:
	xor eax, eax
	mov rcx, init_libos.base
	irp x,edx,ebx,esp,ebp,esi,edi,r8,r9,r10,r11,r12,r13,r14,r15 { xor x, x }
	irp x,0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15 { xorps xmm#x, xmm#x }
	sysretq

.com1:
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
include "allocator.asm"
include "syscall.asm"
include "syslog.asm"

idtr: dw idt.end - idt - 1
      dq idt
gdtr: dw gdt.end - gdt - 1
      dq gdt

exec.end = exec + (1 shl 21)


org 0xffffffffc0e00000
dat:
; "stack is reserved" :^)))))
_stack: rb 1024
.end:
syscall.scratch: dq ?
syslog.head: dq ?
rb ((-$) and 63)  ; pad to cache line

syslog.buffer: rb (1 shl 17)
.end:

allocator.sets: rw ALLOCATOR.SETS
.super:         rw ALLOCATOR.SUPERSETS
.end:

dat.end = dat + (1 shl 21)
