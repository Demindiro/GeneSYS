; == kernel memory layout ==
; 0: 0xffffffffc0000000 - 0xffffffffc0200000 : code  (RX)
;      0xffffffffc01fffe0 - 0xffffffffc0200000 : boot info
; 1: 0xffffffffc0200000 - 0xffffffffc0400000 : MMIO
;      0xffffffffc0200000 - 0xffffffffc0280000 : guard (unmapped)
;      0xffffffffc0280000 - 0xffffffffc0300000 : IOMMU MMIO area
;      0xffffffffc0300000 - 0xffffffffc03fb000 : guard (unmapped)
;      0xffffffffc03fb000 - 0xffffffffc03fc000 : LAPIC
;      0xffffffffc03fd000 - 0xffffffffc03fe000 : guard (unmapped)
;      0xffffffffc03ff000 - 0xffffffffc0400000 : IOAPIC
; 2: 0xffffffffc0400000 - 0xffffffffc0e00000 : guard (unmapped)
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
;
; == LibOS kernel data ==
;
; Most OS-related items are stored in the data area,
; but some such as page tables are stored separately.
;
; 504: 0xfffffffe00000000 - 0xfffffffe40000000 : page tables
; 505: 0xfffffffe40000000 - 0xfffffffe80000000 : guard (unmapped)
; 506: 0xfffffffe80000000 - 0xfffffffec0000000 : PCIe MMCfg
; 507: 0xfffffffec0000000 - 0xffffffff00000000 : guard (unmapped)
; 508: 0xffffffff00000000 - 0xffffffff40000000 : guard (unmapped)
; 509: 0xffffffff40000000 - 0xffffffff80000000 : guard (unmapped)
; 510: 0xffffffff80000000 - 0xffffffffc0000000 : miscellanous
;   256: 0xffffffffa0000000 - 0xffffffffa0200000 : AMD-Vi IOMMU device table
; 511: 0xffffffffc0000000 - 0x0000000000000000 : kernel (see above)

include "kernel.inc"
include "../util/amd-iommu.asm"
include "../util/paging.asm"
include "../util/pci.asm"
include "../util/registers.asm"

paging.base      = 0xfffffffe00000000
paging.base.end  = paging.base + (1 shl 21)

pcie_mmcfg  = 0xfffffffe80000000

iommu = 0xffffffffc0280000
amd_iommu.device_table = 0xffffffffa0000000

init_libos.base  = (1 shl 30) - (1 shl 21)

paging.pml4      = dat.end - 0x1000
paging.pdp       = dat.end - 0x2000
paging.pd        = dat.end - 0x3000
paging.pd_pcie   = dat.end - 0x4000
paging.pt_mmio   = dat.end - 0x5000
paging.pd_paging = dat.end - 0x6000
paging.pd_misc   = dat.end - 0x7000
paging.pml4.pdp     = paging.pml4 + 8*511
paging.pdp.pd       = paging.pdp  + 8*511
paging.pdp.pd_paging = paging.pdp + 8*504
paging.pdp.pd_pcie   = paging.pdp + 8*506
paging.pdp.pd_misc   = paging.pdp + 8*510
paging.pd.code      = paging.pd + 8*0
paging.pd.pt_mmio   = paging.pd + 8*1
paging.pd.data      = paging.pd + 8*7
paging.pt_mmio.ioapic = paging.pt_mmio + 8*511
paging.pt_mmio.lapic  = paging.pt_mmio + 8*509
paging.pt_mmio.iommu  = paging.pt_mmio + 8*128
paging.pd_misc.amd_iommu.device_table = paging.pd_misc + 8*256

irp x,pml4,pdp,pd,pd_paging,pd_pcie,pd_misc,pt_mmio { paging_phys.#x = (2 shl 21) + (paging.#x - dat.end) }

MSR.IA32_EFER = 0xc0000080
IA32_EFER.SCE = 1 shl  0
IA32_EFER.LME = 1 shl  8
IA32_EFER.NXE = 1 shl 11

LIBOS.FLAGS.INTR_DEBUG_PENDING = 0
LIBOS.INTR.TIMER =  1
LIBOS.INTR.DEBUG = 31

virtual at iommu
	amd_iommu.decl_mmio iommu.amd
end virtual

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
	; list of PCIe root bases
	.pcie:        rb (PCIE.MAX_ROOTS * 16)
end virtual
exec:
	; clear data region
	mov ecx, (dat.end - dat) / 8
	mov rdi, dat
	xor eax, eax
	rep stosq

	; copy GDT to data region
	; the CPU insists on setting 0x89 to 0x8b in TSS segment
	; and we can't load it with 0x8b already set,
	; so it must be put in a R/W region.
	mov rsi, init_gdt
	mov rdi, gdt
	mov ecx, (gdt.end - gdt) / 8
	rep movsq

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
	; TSS
	mov word [tss.iopb], tss.end - tss
	mov qword [tss.rsp0], _stack.end
	mov qword [tss.ist1], _stack.end
	mov ax, GDT.TSS
	ltr ax

	; load initial page table and ensure all global mappings are flushed.
	mov rax, cr4
	and rax, not CR4.PGE
	mov cr4, rax
	mov rax, [bootinfo.init_pagetable]
	mov cr3, rax

	; construct new page table
	mov rbx, [bootinfo.phys_base]
	; PD
	lea rax, [rbx + (0 shl 21) + PAGE.A + PAGE.D + PAGE.PS + PAGE.G + PAGE.P]
	mov [paging.pd.code], rax
	lea rax, [rbx + (1 shl 21) + PAGE.A + PAGE.D + PAGE.PS + PAGE.RW + PAGE.G + PAGE.P]
	mov [paging.pd.data], rax
	lea rax, [rbx + paging_phys.pt_mmio   + PAGE.A + PAGE.D + PAGE.RW + PAGE.P]
	mov [paging.pd.pt_mmio  ], rax
	; PDP
	lea rax, [rbx + paging_phys.pd  + PAGE.A + PAGE.D + PAGE.RW + PAGE.P]
	mov [paging.pdp.pd], rax
	lea rax, [rbx + paging_phys.pd_pcie   + PAGE.A + PAGE.D + PAGE.RW + PAGE.P]
	mov [paging.pdp.pd_pcie  ], rax
	lea rax, [rbx + paging_phys.pd_paging + PAGE.A + PAGE.D + PAGE.RW + PAGE.P]
	mov [paging.pdp.pd_paging], rax
	lea rax, [rbx + paging_phys.pd_misc   + PAGE.A + PAGE.D + PAGE.RW + PAGE.P]
	mov [paging.pdp.pd_misc  ], rax
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

	mov r13, [bootinfo.memmap.start]
	mov r12, [r13]

.init_pagetables:
	; allocate and initialize page table
	call _init.alloc_2m
	mov rbx, paging.base
	sub rax, rbx
	mov [paging.virt_to_phys], rax
	add rax, rbx
	or rax, PAGE.PS or PAGE.RW or PAGE.P
	mov [paging.pd_paging], rax
	; zero out entire page
	mov ecx, (paging.base.end - paging.base) / 8
	mov rdi, paging.base
	xor eax, eax
	rep stosq
	; create linked chain of tables
	mov rdi, paging.base
	mov rbx, paging.base.end
	mov [paging.free_table], rdi
	mov rsi, rdi
@@:	add rsi, 0x1000
	mov [rdi], rsi
	mov rdi, rsi
	cmp rsi, rbx
	jne @b

.init_rest:
	call paging.init
	call syscall.init
	mov qword [syslog.head], 0
	mov edx, COM1.IOBASE
	; initialize ioapic and lapic as the very first thing
	; so we don't confuse COMx interrupts
	call ioapic.init
	call lapic.init
	call comx.init
	call debug.init

.init_pcie_mmcfg:
	mov  rax, [bootinfo.pcie]
	mov  rdi, paging.pd_pcie
	or   rax, PAGE.P + PAGE.PS + PAGE.RW
	mov  ecx, 128  ; = 256M / 2M
@@:	stosq
	add  rax, 1 shl 21
	loop @b

.scan_amd_iommu:
	mov  rsi, pcie_mmcfg
	lea  rbx, [rsi + (1 shl 28)]
@@:	mov  eax, [rsi + PCI.MMCFG.class]
	shr  eax, 8
	cmp  eax, 0x080600
	je   .found_amd_iommu
	add  rsi, 1 shl 12
	cmp  rsi, rbx
	jne  @b
	jmp panic.no_iommu

.found_amd_iommu:
	push    rsi
	mov     rsi, trace.found_amd_iommu
	call    syslog.push_minimsg
	pop     rsi
	mov     eax, [rsi + PCI.MMCFG.cap_ptr]
	movzx   eax, al
@@:	test    eax, eax
	jz      panic.amd_iommu_missing_cap
	mov     edx, [rsi + rax]
	cmp     dl, 0xf
	je      .found_amd_iommu.cap
	movzx   eax, dh
	jmp     @b

.found_amd_iommu.cap:
	shr     edx, 16
	cmp     dl, 1011b  ; 48882-PUB—Rev 3.10—Feb 2025
	je      .amd_iommu_supported
	cmp     dl, 0011b ; ... whatever QEMU is
	jne     panic.amd_iommu_bad_version

.amd_iommu_supported:
	add     rsi, rax
	mov     [amd_iommu.pcie_mmcfg.cap], rsi
	mov     eax, [rsi + 8]
	mov     edx, [rsi + 4]
	shr     rax, 32
	or      rax, rdx
	or      edx, 1
	mov     [rsi + 4], edx
	and     rax, not 0xfff
	or      rax, PAGE.P + PAGE.RW
	mov     ecx, 4  ; TODO check for 16K or 512K
	mov     rdi, paging.pt_mmio.iommu
@@:	stosq
	add     rax, 1 shl 12
	loop    @b
	; enable memory space access
	mov     rsi, [amd_iommu.pcie_mmcfg.cap]
	and     rsi, not 0xfff
	mov     dword [rsi + 4], 2

.amd_iommu_reset:
	; TODO is there a proper reset option? Is it even necessary?
	xor     eax, eax
	;mov     [iommu.amd.control     ], rax

.amd_iommu_init:
	call    _init.alloc_2m
	or      rax, PAGE.P + PAGE.PS + PAGE.RW + PAGE.G
	mov     [paging.pd_misc.amd_iommu.device_table], rax
	or      rax, 0x1ff  ; maximum size (2MiB / 4KiB - 1 = 511)
	mov     qword [iommu.amd.device_table], rax
	mov     rax, (1 shl 21) + (iommu.command_buf - dat) + (8 shl 56)
	add     rax, [bootinfo.phys_base]
	mov     [iommu.amd.command_ring], rax
	add     rax, iommu.event_buf - iommu.command_buf
	mov     [iommu.amd.event_ring  ], rax
	mov     rdi, amd_iommu.device_table
	mov     ecx, (1 shl 21) / 8
	xor     eax, eax
	rep stosq

.amd_iommu_enable:
	mov     [iommu.amd.control], AMD_IOMMU.CONTROL.IOMMU_EN + AMD_IOMMU.CONTROL.EVENT_LOG_EN + AMD_IOMMU.CONTROL.CMD_BUF_EN

.amd_iommu_test:
	; do a test to check if the IOMMU responds in an expected manner
	mov     rax, AMD_IOMMU.CMD.COMPLETION_WAIT shl 60
	mov     [iommu.command_buf + 0], rax
	xor     eax, eax
	mov     [iommu.command_buf + 8], rax
	mov     [iommu.amd.command_tail], 16 * 1
	mov     rdi, iommu.command_buf
	; TODO we ought to use a timer
	; use a very low amount of cycles for now
	mov     ecx, 1000
@@:	cmp     [iommu.amd.command_head], 16 * 1
	je      @f
	pause
	loop    @b
	jmp     panic.amd_iommu_no_response
@@:


.load_libos:
	; OS code/data
	call _init.alloc_2m
	mov  rdi, init_libos.base
	lea  rsi, [rax + PAGE.P + PAGE.PS + PAGE.RW + PAGE.US]
	call paging.map_2m
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

; inputs:    r12, r13
; outputs:   rax=physical base, r12, r13
; clobbers:  rdx
_init.alloc_2m:
	; align to 2M boundary and step
	add  r12, not (-1 shl 21)
	and  r12,     (-1 shl 21)
	mov  rax, r12
	add  r12, 1 shl 21
	; ensure the page is within the current region
	cmp  r12, [r13 + 8]
	ja   .next_region
	; ensure the page isn't already used by the kernel
	mov  rdx, rax
	sub  rdx, [bootinfo.phys_base]
	cmp  rdx, 2 shl 21
	jb   _init.alloc_2m
	ret
.next_region:
	add  r13, 16
	mov  r12, [r13]
	jmp  _init.alloc_2m


panic.no_iommu:
	mov  rsi, panic_msg.no_iommu
	jmp  panic_minimsg

panic.amd_iommu_missing_cap:
	mov  rsi, panic_msg.amd_iommu_missing_cap
	jmp  panic_minimsg

panic.amd_iommu_bad_version:
	mov  rsi, panic_msg.amd_iommu_bad_version
	jmp  panic_minimsg

panic.amd_iommu_no_response:
	mov  rsi, panic_msg.amd_iommu_no_response
	jmp  panic_minimsg

panic_minimsg:
	movzx ecx, byte [rsi]
	inc   rsi
	; fallthrough

; enable interrupts and halt forever.
; interrupts need to be enabled so the debug interface works.
;
; inputs: rsi=msg base  rcx=msg len
panic:
	call syslog.push
halt:
	sti
	hlt
	jmp halt

include "../common/gdt.asm"
include "../common/crc32c.asm"
include "syslog.asm"
include "ioapic.asm"
include "lapic.asm"
include "comx.asm"
include "debug.asm"
include "idt.asm"
include "syscall.asm"
include "paging.asm"

idtr: dw idt.end - idt - 1
      dq idt
gdtr: dw gdt.end - gdt - 1
      dq gdt

trace.found_amd_iommu: db 16, "Found AMD IOMMU", 10
panic_msg.no_iommu: db 16, "No IOMMU found!", 10
panic_msg.amd_iommu_missing_cap: db 35, "AMD IOMMU missing PCIe capability!", 10
panic_msg.amd_iommu_bad_version: db 31, "Unsupported AMD IOMMU version!", 10
panic_msg.amd_iommu_no_response: db 37, "AMD IOMMU does not reply to command!", 10

exec.end = exec + (1 shl 21)


virtual at _iommu_shared
	amd_iommu.pcie_mmcfg.cap: dq ?
	amd_iommu.mmio_base:      dq ?
end virtual

org 0xffffffffc0e00000
dat:
; "stack is reserved" :^)))))
_stack: rb 1024
.end:
syslog.head: dq ?
libos.sysconf_base: dq ?
libos.flags:        dq ?
debug.tx.head: dd ?
debug.tx.tail: dd ?
paging.free_table:   dq ?
paging.virt_to_phys: dq ?
_iommu_shared:  rq 2
rb ((-$) and 63)  ; pad to cache line

syslog.buffer: rb SYSLOG.BUFFER_SIZE
.end:

rb ((-$) and 7)

gdt: rb init_gdt.end - init_gdt
.end:

	dd ?
tss:
	dd ?
	irp x,0,1,2 { .rsp#x: dq ? }
	dd ?, ?
	irp x,1,2,3,4,5,6,7 { .ist#x: dq ? }
	dd ?, ?
	dw ?
.iopb: dw ?
.end:

debug.tx.buffer: rb DEBUG.TX.BUFFER_SIZE
debug.rx.buffer: rb DEBUG.RX.BUFFER_SIZE
debug.rx.len: dw ?
debug.rx.cap: dw ?
debug.rx.prev: db ?

rb ((-$) and 4095)  ; pad to page size
iommu.command_buf:  rb 4096
iommu.event_buf:    rb 4096

dat.end = dat + (1 shl 21)
