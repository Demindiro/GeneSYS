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
EFI_SYSTEM_TABLE.Hdr              = 0 ; EFI_TABLE_HEADER
EFI_SYSTEM_TABLE.FirmwareVendor   = 24 ; CHAR16
EFI_SYSTEM_TABLE.FirmwareRevision = 32 ; UINT32
EFI_SYSTEM_TABLE.ConsoleInHandle  = 40 ; EFI_HANDLE
EFI_SYSTEM_TABLE.ConIn            = 48 ; EFI_SIMPLE_TEXT_INPUT_PROTOCOL
EFI_SYSTEM_TABLE.ConsoleOutHandle = 56 ; EFI_HANDLE
EFI_SYSTEM_TABLE.ConOut           = 64 ; EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL
; there's more but idc

; 12.4.1
EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL.Reset        = 0 ; EFI_TEXT_RESET
EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL.OutputString = 8 ; EFI_TEXT_STRING

macro print string {
	; 12.4.3
	; typedef EFI_STATUS (EFIAPI *EFI_TEXT_STRING) (
	;   IN EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL *This
	;   IN CHAR16 *String
	; );
	mov rdx, [rsp]
	mov rcx, [rdx + EFI_SYSTEM_TABLE.ConOut]
	lea rdx, [string]
	sub rsp, 32
	call qword [rcx + EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL.OutputString]
	add rsp, 32
}

; rcx: EFI_HANDLE (of ourselves, just ignore)
; rdx: EFI_SYSTEM_TABLE*
start:
	push rbp
	mov rbp, rsp
	push rcx
	push rdx

	print hello_uefi
	print hello_uefi
	print hello_uefi
	print hello_uefi

	cli
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

include "../common/comx.asm"

hello_uefi: dw 'H', 'e', 'l', 'l', 'o', ' ', 'U', 'E', 'F', 'I', '!', 13, 10, 0

times ((-$) and 0xfff) db 0

text_end:
