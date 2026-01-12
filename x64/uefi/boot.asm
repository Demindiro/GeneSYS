use64

org 0

IMAGE_FILE_EXECUTABLE_IMAGE    = 1 shl  1
IMAGE_FILE_LARGE_ADDRESS_AWARE = 1 shl 5

IMAGE_SCN_CNT_CODE    = 0x20
IMAGE_SCN_MEM_EXECUTE = 0x20000000
IMAGE_SCN_MEM_READ    = 0x40000000

dos:
	db "MZ"
	times 58 db 0
	dd pe
pe:
	db "PE", 0, 0
	dw 0x8664 ; machine type
	dw 1      ; sections
	dd 0, 0, 0
	dw .opt.end - .opt
	dw IMAGE_FILE_EXECUTABLE_IMAGE or IMAGE_FILE_LARGE_ADDRESS_AWARE
.opt:
	dw 0x20b, 0
	dd text_end     ; size of code
	dd 0, 0         ; size of data
	dd start, start ; entry, code base
	dq 0            ; image base (irrelevant, PIE)
	dd 4096, 4096   ; alignment
	dd 0, 0, 0, 0
	dd text_end     ; image size
	dd pe.end       ; headers size
	dd 0
	dw 10           ; EFI subsystem
	dw 0
	dq 0, 0, 0, 0   ; stack/heap (irrelevant)
	dd 0, 0         ; RVA
.opt.end:
	db ".david", 0, 0
	times 2 \
	dd text_end - start, start  ; virtual/raw size/addr
	dd 0, 0, 0      ; ptr to reloc/lines, num
	dd IMAGE_SCN_CNT_CODE or IMAGE_SCN_MEM_EXECUTE or IMAGE_SCN_MEM_READ
.end:


EFI_HANDLE.sizeof = 8 ; VOID*

; 4.2.1
EFI_TABLE_HEADER.sizeof = 8 + (4 * 4)

; 4.3.1
EFI_SYSTEM_TABLE.Hdr                  = 0 ; EFI_TABLE_HEADER
EFI_SYSTEM_TABLE.FirmwareVendor       = 24 ; CHAR16 *
EFI_SYSTEM_TABLE.FirmwareRevision     = 32 ; UINT32
EFI_SYSTEM_TABLE.ConsoleInHandle      = 40 ; EFI_HANDLE
EFI_SYSTEM_TABLE.ConIn                = 48 ; EFI_SIMPLE_TEXT_INPUT_PROTOCOL *
EFI_SYSTEM_TABLE.ConsoleOutHandle     = 56 ; EFI_HANDLE
EFI_SYSTEM_TABLE.ConOut               = 64 ; EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL *
EFI_SYSTEM_TABLE.StandardErrorHandle  = 72 ; EFI_HANDLE
EFI_SYSTEM_TABLE.StdErr               = 80 ; EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL *
EFI_SYSTEM_TABLE.RuntimeServices      = 88 ; EFI_RUNTIME_SERVICES *
EFI_SYSTEM_TABLE.BootServices         = 96 ; EFI_BOOT_SERVICES *
EFI_SYSTEM_TABLE.NumberOfTableEntries = 104 ; UINTN
EFI_SYSTEM_TABLE.ConfigurationTable   = 112 ; EFI_CONFIGURATION_TABLE *

; 4.4.1
EFI_BOOT_SERVICES.Hdr = 0
x = 24
macro f name {
	EFI_BOOT_SERVICES.#name = x
	x = x + 8
}
; Task priority
f RaiseTpl
f RestoreTpl
; Memory
f AllocatePages
f FreePages
f GetMemoryMap
f AllocatePool
f FreePool
; Event & Timer
f CreateEvent
f SetTimer
f WaitForEvent
f SignalEvent
f CloseEvent
f CheckEvent
; Protocol handler
f InstallProtocolInterface
f ReinstallProtocolInterface
f UninstallProtocolInterface
f HandleProtocol
f Reserved
f RegisterProtocolNotify
f LocateHandle
f LocateDevicePath
f InstallConfigurationTable
; Image Services
f LoadImage
f StartImage
f Exit
f UnloadImage
f ExitBootServices
; Miscellaneous Services
f GetNextMonotonicCount
f Stall
f SetWatchdogTimer
; DriverSupport Services
f ConnectController     ; EFI 1.1+
f DisconnectController  ; EFI 1.1+
; Open and Close Protocol
f OpenProtocol             ; EFI 1.1+
f CloseProtocol            ; EFI 1.1+
f OpenProtocolInformation  ; EFI 1.1+
; Library
f ProtocolsPerHandle  ; EFI 1.1+
f LocateHandleBuffer  ; EFI 1.1+
f LocateProtocol      ; EFI 1.1+
f InstallMultipleProtocolInterfaces   ; EFI 1.1+
f UninstallMultipleProtocolInterfaces ; EFI 1.1+
; 32-bit CRC Services
f CalculateCrc32  ; EFI 1.1+
; Miscellaneous Services
f CopyMem         ; EFI 1.1+
f SetMem          ; EFI 1.1+
f CreateEventEx   ; UEFI 2.0+
purge f, x

; 7.2.1 EFI_BOOT_SERVICES.AllocatePages()
x = 0
macro f name {
	name = x
	x = x + 1
}
f AllocateAnyPages
f AllocateMaxAddress
f AllocateAddress
f MaxAllocateType
x = 0
f EfiReservedMemoryType
usable_memory_types.0.start = x
f EfiLoaderCode
f EfiLoaderData
f EfiBootServicesCode
f EfiBootServicesData
usable_memory_types.0.end = x
f EfiRuntimeServicesCode
f EfiRuntimeServicesData
f EfiConventionalMemory
f EfiUnusableMemory
f EfiACPIReclaimMemory
f EfiACPIMemoryNVS
f EfiMemoryMappedIO
f EfiMemoryMappedIOPortSpace
f EfiPalCode
f EfiPersistentMemory
f EfiUnacceptedMemoryType
f EfiMaxMemoryType
purge f, x

; 7.2.3 EFI_BOOT_SERVICES.GetMemoryMap()
EFI_MEMORY_DESCRIPTOR.Type          = 0
EFI_MEMORY_DESCRIPTOR.PhysicalStart = 8
EFI_MEMORY_DESCRIPTOR.VirtualStart  = 16
EFI_MEMORY_DESCRIPTOR.NumberOfPages = 24
EFI_MEMORY_DESCRIPTOR.Attribute     = 32

; 12.4.1
EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL.Reset        = 0 ; EFI_TEXT_RESET
EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL.OutputString = 8 ; EFI_TEXT_STRING


efi_invalid_parameter = (1 shl 63) or 2
efi_buffer_too_small  = (1 shl 63) or 5
efi_out_of_resources  = (1 shl 63) or 9


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

CR4.PGE     =  1 shl  7
CR4.PCID    =  1 shl 17

; https://board.flatassembler.net/topic.php?t=8619
rodata._list equ
macro rodata {
	local x
	rodata._list equ rodata._list,x
	macro x
}

macro uefi._tracemsg lbl, str {
	rodata
	\{
		local e
		lbl: db e - $, str
		e:
	\}
}
macro uefi.trace str {
	local t
	uefi._tracemsg t, str
	lea rsi, [t]
	call uefi._trace
}
macro uefi.assertgez reg, msg {
	local t
	uefi._tracemsg t, msg
	lea rsi, [t]
	test reg, reg
	jl uefi._panic
}

; "fast"call my ass
; (don't make it more complicated, please)
macro eficall target {
	sub rsp, 32
	call target
	add rsp, 32
}

; rcx: EFI_HANDLE (of ourselves)
; rdx: EFI_SYSTEM_TABLE*
start:
virtual at r13
	.handle:      dq ?
	.kernel_phys: dq ?
end virtual
	push rbp
	; r15 => System table
	; r14 => BootServices
	; [r13 + 0] => handle
	; [r13 + 8] => kernel phys base
	; r12 => CR3
	mov r15, rdx
	mov r14, [r15 + EFI_SYSTEM_TABLE.BootServices]
	sub rsp, 16
	mov r13, rsp
	mov [.handle], rcx

	lea rsi, [hello_uefi]
	mov ecx, 12
	call uefi.println

	uefi.trace "allocate kernel code/data"
	; 7.2.1 EFI_BOOT_SERVICES.AllocatePages()
	; typedef EFI_STATUS (EFIAPI *EFI_ALLOCATE_PAGES) (
	;   IN EFI_ALLOCATE_TYPE Type,
	;   IN EFI_MEMORY_TYPE MemoryType,
	;   IN UINTN Pages,
	;   IN OUT EFI_PHYSICAL_ADDRESS *Memory
	; );
	mov ecx, AllocateAnyPages
	mov edx, EfiLoaderData
	; allocate 6M, then round up to 2M boundary,
	; leaving us with at least 4M of available memory.
	mov r8, 3 shl (21 - 12) ; *page* count, not bytes :)
	push rax ; base
	mov r9, rsp
	push rax ; align stack
	eficall qword [r14 + EFI_BOOT_SERVICES.AllocatePages]
	uefi.assertgez rax, "heap allocation failed"

	uefi.trace "mapping kernel"
	pop rax  ; align stack
	pop rdi  ; base

	; align to 2M
	add rdi, not (-1 shl 21)
	and rdi,     (-1 shl 21)
	mov [.kernel_phys], rdi

	; code
	lea rsi, [kernel.header.end]
	mov ecx, [kernel.exec.size]
	rep movsb
	mov ecx, edi
	neg ecx
	and ecx, not (-1 shl 21)
	xor eax, eax
	rep stosb

	; data
	mov ecx, [kernel.data.size]
	rep movsb
	mov ecx, edi
	neg ecx
	and ecx, not (-1 shl 21)
	mov edx, 1 shl 21
	cmp dword [kernel.data.size], 0
	cmove ecx, edx ; if data.size == 0 then ecx = 2M
	rep stosb

	; PD: 0 -> code, 7 -> data
	lea rax, [rdi - (2 shl 21) + PAGE.P + PAGE.PS + PAGE.G]
	lea rdx, [rdi - (1 shl 21) + PAGE.P + PAGE.PS + PAGE.G + PAGE.RW]
	;lea rax, [rdi - (2 shl 21) + PAGE.P + PAGE.PS]
	;lea rdx, [rdi - (1 shl 21) + PAGE.P + PAGE.PS + PAGE.RW]
	mov [rdi - 0x1000 + (8*0)], rax
	mov [rdi - 0x1000 + (8*7)], rdx
	; PDP: 511
	lea rax, [rdi - 0x1000 + PAGE.P + PAGE.RW]
	mov [rdi - 0x2000 + (511*8)], rax
	; PML4: 511
	lea rax, [rdi - 0x2000 + PAGE.P + PAGE.RW]
	mov [rdi - 0x3000 + (511*8)], rax
	; identity map
	mov rsi, cr3
	sub rdi, 0x3000
	mov r12, rdi
	mov ecx, 256
	rep movsq

	uefi.trace "GetMemoryMap + ExitBootServices" ; no tracing or any UEFI routines between these two calls!
	; attempt stack alloc to simplify things
	; we have at least 128KiB, use half of that
	; ... which surely is enough, right?
	mov ecx, 1 shl 16
	sub rsp, rcx
	; 7.2.3 EFI_BOOT_SERVICES.GetMemoryMap()
	; typedef EFI_STATUS (EFIAPI *EFI_GET_MEMORY_MAP) (
	;   IN OUT UINTN *MemoryMapSize,
	;   OUT EFI_MEMORY_DESCRIPTOR *MemoryMap,
	;   OUT UINTN *MapKey,
	;   OUT UINTN *DescriptorSize,
	;   OUT UINT32 *DescriptorVersion
	; );
	mov rdx, rsp        ; MemoryMap
	push rax            ; align
	push rcx            ; *MemoryMapSize
	mov rcx, rsp        ; MemoryMapSize
	sub rsp, 24
	lea r8, [rsp + 16]  ; MapKey
	lea r9, [rsp +  8]  ; DescriptorSize
	push rsp            ; DescriptorVersion
	eficall qword [r14 + EFI_BOOT_SERVICES.GetMemoryMap]
	uefi.assertgez rax, "GetMemoryMap failed"
	pop rax  ; DescriptorVersion  (ignore)
	pop rax  ; *DescriptorVersion (ignore)
	pop rbx  ; *DescriptorSize
	pop rdx  ; *MapKey
	pop rcx  ; *MemoryMapSize
	pop rax  ; align

	push rdx
.copy_memmap:
	mov rdi, [.kernel_phys]
	add rdi, (1 shl 21) - BOOTINFO.sizeof
	lea rsi, [rsp + 8]
	add rcx, rsi
@@:	mov eax, [rsi + EFI_MEMORY_DESCRIPTOR.Type]
	cmp eax, EfiConventionalMemory
	je .a
	sub eax, usable_memory_types.0.start
	cmp eax, usable_memory_types.0.end - usable_memory_types.0.start
	jae .n
.a:	sub rdi, 16
	mov rdx, [rsi + EFI_MEMORY_DESCRIPTOR.NumberOfPages]
	mov rax, [rsi + EFI_MEMORY_DESCRIPTOR.PhysicalStart]
	shl rdx, 12
	add rdx, rax
	mov [rdi + 0], rax
	mov [rdi + 8], rdx
.n:	add rsi, rbx
	cmp rsi, rcx
	jne @b

	mov rsi, [.kernel_phys]
	add rsi, (1 shl 21) - BOOTINFO.sizeof
	call memmap.radixsort
	call memmap.merge

	; 7.4.6 EFI_BOOT_SERVICES.ExitBootServices()
	; EFI_STATUS (EFIAPI *EFI_EXIT_BOOT_SERVICES) (
	;   IN EFI_HANDLE ImageHandle,
	;   IN UINTN MapKey
	; );
	pop rdx
	mov rcx, [.handle]
	push rdi  ; memmap start
	push rsi  ; memmap end
	eficall qword [r14 + EFI_BOOT_SERVICES.ExitBootServices]
	uefi.assertgez rax, "ExitBootServices failed"

.bootinfo:
	pop rsi   ; memmap end
	pop rdi   ; memmap start
	mov rax, [.kernel_phys]
	; bootinfo must be put at end of code regio
	lea rbx, [rax + ((1 shl 21) - BOOTINFO.sizeof)]
	mov [rbx + BOOTINFO.phys_base   ], rax
	; we used physical addresses while populating the memory map
	; to avoid touching the UEFI page table, but the kernel expects
	; virtual addresses
	mov rdx, KERNEL.DATA.START - (1 shl 21)
	sub rdx, rax
	; cr3 points to the very last page we allocated
	lea rcx, [rdx + r12]
	mov [rbx + BOOTINFO.data_free   ], rcx
	mov rdx, KERNEL.CODE.START
	sub rdx, rax
	lea rcx, [rdx + rdi]
	mov [rbx + BOOTINFO.memmap.start], rcx
	lea rcx, [rdx + rsi]
	mov [rbx + BOOTINFO.memmap.end  ], rcx

	; enter kernel
	cli
	mov cr3, r12
	lgdt [kernel.gdtr]
	mov ax, KERNEL.GDT.KERNEL_SS
	mov ds, ax
	mov es, ax
	mov ss, ax
	mov fs, ax
	mov gs, ax
	lea rax, [@f]
	push KERNEL.GDT.KERNEL_CS
	push rax
	retfq
@@:	lidt [kernel.idtr]
	mov rbp, KERNEL.CODE.START
	jmp rbp

; rsi: prefixed string base
;
; preserved: rax, rcx, rdx, rbx, rdi
uefi._trace:
	push rax
	push rcx
	push rdx
	lodsb
	movzx ecx, al
	call uefi.println
	pop rdx
	pop rcx
	pop rax
	ret
; rsi: string base
; rcx: string length
uefi.println:
	push rbp
	call uefi.print
	pop rbp
	lea rsi, [uefi.println._crlf]
	mov ecx, 2
; rsi: string base
; rcx: string length
uefi.print:
	push rbp
	; TODO length checking
	sub rsp, 1024
	lea rdi, [rsp + 32]
	mov rdx, rdi
	mov ah, 0
@@:	lodsb
	stosw
	loop @b
	xor eax, eax
	stosd
	; 12.4.3
	; typedef EFI_STATUS (EFIAPI *EFI_TEXT_STRING) (
	;   IN EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL *This
	;   IN CHAR16 *String
	; );
	mov rcx, [r15 + EFI_SYSTEM_TABLE.ConOut]
	lea rdx, [rsp + 32]
	call qword [rcx + EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL.OutputString]
	add rsp, 1024
	pop rbp
	ret

uefi._panic:
	call uefi._trace
@@:	cli
	hlt
	jmp @b


; rdi: range start (incl)
; rsi: range end   (excl)
;
; Each element is [start, end). Only start is considered.
;
; The algorithm is in-place radix sort using a single bit as radix.
; This isn't very efficient but it is very simple.
;
; It uses at most 16*40 = 640 bytes on the stack.
memmap.radixsort:
	xor ebx, ebx
	bts rbx, 51  ; x86 supports at most 52 physical bits

.iter:
	cmp rdi, rsi
	je .r
	mov r10, rdi
	; 1. count zero bits
	xor ecx, ecx
@@:	xor edx, edx
	test [rdi], rbx
	setz dl
	add rdi, 16
	add ecx, edx
	cmp rdi, rsi
	jne @b
	; 2. swap elements with one bit to high partition
	mov rdi, r10
	shl ecx, 4
	add rcx, rdi
	push rcx         ; mid
@@:	xor edx, edx
	test [rdi], rbx
	jz .n
	xor edx, 16
	movaps xmm0, [rdi]
	movaps xmm1, [rcx]
	movaps [rcx], xmm0
	movaps [rdi], xmm1
.n:	add rcx, rdx
	xor edx, 16
	add rdi, rdx
	cmp rcx, rsi
	jne @b
	mov rdi, r10
	; recursively sort partitions
	pop  rcx
	cmp rbx, 1 shl 12  ; bits 0-11 are guaranteed to be zero
	jl .r
	shr rbx, 1
	push rsi
	mov  rsi, rcx
	call .iter
	pop  rcx
	push rdi
	mov  rdi, rsi
	mov  rsi, rcx
	call .iter
	pop rdi
	shl rbx, 1
.r:	ret

; Join contiguous regions.
;
; rdi: range start (incl) => new base
; rsi: range end   (excl)
memmap.merge:
	push rsi
	lea rbx, [rsi - 32]
	sub rsi, 16
@@:	mov rax, [rsi]
	cmp rax, [rbx + 8]
	ja .n
	mov rax, [rbx]
	mov [rsi], rax
	jmp .c
.n:	sub rsi, 16
	movaps xmm0, [rbx]
	movaps [rsi], xmm0
.c:	sub rbx, 16
	cmp rbx, rdi
	jne @b
	mov rdi, rsi
	pop rsi
	ret


uefi.println._crlf: db 13, 10
hello_uefi: db "Hello, UEFI!"
match y,rodata._list { irp x,y { x } }

BOOTINFO.sizeof       = 32
BOOTINFO.phys_base    =  0
BOOTINFO.data_free    =  8
BOOTINFO.memmap.start = 16
BOOTINFO.memmap.end   = 24

KERNEL.CODE.START = 0xffffffffc0000000
KERNEL.CODE.END   = KERNEL.CODE.START + (1 shl 21)
KERNEL.DATA.START = KERNEL.CODE.START + (7 shl 21)
KERNEL.DATA.END   = KERNEL.DATA.START + (1 shl 21)
kernel.magic      = kernel +  0
kernel.exec.size  = kernel +  8
kernel.data.size  = kernel + 12
kernel.idtr       = kernel + 16
kernel.gdtr       = kernel + 26
kernel._reserved  = kernel + 36
kernel.header.end = kernel + 64
KERNEL.GDT.KERNEL_CS = 0x08
KERNEL.GDT.KERNEL_SS = 0x10
align 64
; TODO avoid hardcoded path
kernel: file "../../build/uefi/kernel.bin"
.end:

times ((-$) and 0xfff) db 0

text_end:
