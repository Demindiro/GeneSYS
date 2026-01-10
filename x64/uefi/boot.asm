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
f EfiReservedMemoryType
f EfiLoaderCode
f EfiLoaderData
f EfiBootServicesCode
f EfiBootServicesData
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
	push rbp
	; r15 => System table
	; r14 => BootServices
	; r12 => handle
	mov r15, rdx
	mov r14, [r15 + EFI_SYSTEM_TABLE.BootServices]
	mov r12, rcx

	lea rsi, [hello_uefi]
	mov ecx, 12
	call uefi.println

	uefi.trace "GetMemoryMap (size only)"
	xor ecx, ecx
	call uefi.get_memory_map
	cmp rax, [efi_buffer_too_small]
	je @f
	uefi._tracemsg start.err_memmapsize, "GetMemoryMap (size only) failed"
	lea rsi, [start.err_memmapsize]
	test rax, rax
	jl uefi._panic
@@:

	; attempt stack alloc to simplify things
	; we have at least 64KiB, use 3/4 of that
	; ... this does make the earlier call redundant,
	; but it will be easier to switch to heap alloc, so keep it.
	uefi._tracemsg start.err_memmap_too_large, "GetMemoryMap (size only) too large"
	lea rsi, [start.err_memmap_too_large]
	cmp rcx, (1 shl 15) + (1 shl 14)
	ja uefi._panic
	sub rsp, (1 shl 15) + (1 shl 14)

	uefi.trace "GetMemoryMap + ExitBootServices" ; no tracing or any UEFI routines between these two calls!
	mov rdx, rsp
	call uefi.get_memory_map
	uefi.assertgez rax, "GetMemoryMap failed"

if 0 ; TODO
	; convert to simpler memory mapping
	mov rsi, rsp
	mov rdi, rsp
	lea rdi, [rsi + rcx]
@@:
	sub rcx, rbx
	jnz @b
end if

	; 7.4.6 EFI_BOOT_SERVICES.ExitBootServices()
	; EFI_STATUS (EFIAPI *EFI_EXIT_BOOT_SERVICES) (
	;   IN EFI_HANDLE ImageHandle,
	;   IN UINTN MapKey
	; );
	mov rcx, r12
	eficall qword [r14 + EFI_BOOT_SERVICES.ExitBootServices]
	uefi.assertgez rax, "ExitBootServices failed"

	jmp boot.start

; rsi: prefixed string base
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

; rdx: memory map base
; rcx: memory map capacity
;
; rax: => status
; rdi: => descriptor version
; rbx: => descriptor size
; rdx: => map key (for ExitBootServices)
; rcx: => memory map size
uefi.get_memory_map:
	push rbp
	; 7.2.3 EFI_BOOT_SERVICES.GetMemoryMap()
	; typedef EFI_STATUS (EFIAPI *EFI_GET_MEMORY_MAP) (
	;   IN OUT UINTN *MemoryMapSize,
	;   OUT EFI_MEMORY_DESCRIPTOR *MemoryMap,
	;   OUT UINTN *MapKey,
	;   OUT UINTN *DescriptorSize,
	;   OUT UINT32 *DescriptorVersion
	; );
	push rbp      ; align (one stack arg)
	push rcx      ; *MemoryMapSize
	mov rcx, rsp  ; MemoryMapSize
	push rax
	mov r8, rsp   ; MapKey
	push rax
	mov r9, rsp   ; DescriptorSize
	push rax
	push rsp      ; DescriptorVersion
	eficall qword [r14 + EFI_BOOT_SERVICES.GetMemoryMap]
	pop rdi ; DescriptorVersion
	pop rdi ; *DescriptorVersion
	pop rbx ; *DescriptorSize
	pop rdx ; *MapKey
	pop rcx ; *MemoryMapSize
	pop rbp ; align
	pop rbp
	ret

uefi.println._crlf: db 13, 10
hello_uefi: db "Hello, UEFI!"
match y,rodata._list { irp x,y { x } }

; UEFI status codes are totally dumb
; thanks for making them 64-bit...
;efi_invalid_parameter: dq (1 shl 63) or 2
efi_buffer_too_small:  dq (1 shl 63) or 5

; TODO avoid hardcoded path
;boot.start = -(1 shl 21) - (1 shl 12)
boot.start:
file "../../build/uefi/kernel.bin"
;include "../common/boot.asm"

times ((-$) and 0xfff) db 0

text_end:
