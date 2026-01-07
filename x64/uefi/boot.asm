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



COM1.IOBASE = 0x3f8
COMx.rx          = 0
COMx.tx          = 0
COMx.intr_enable = 1
COMx.intr_id     = 2
COMx.baud_lo     = 0
COMx.baud_hi     = 1
COMx.ctrl_fifo   = 2
COMx.ctrl_line   = 3
COMx.ctrl_modem  = 4
COMx.stat_line   = 5
COMx.stat_modem  = 6
COMx.scratch     = 7

com1:
macro outbi val {
	mov al, val
	out dx, al
}
.init:
	print com1_init
	mov dx, COM1.IOBASE + COMx.ctrl_line
	outbi 1 shl 7
	mov dx, COM1.IOBASE + COMx.baud_lo
	outbi 1 ; 115200
	inc dx  ; baud_hi
	outbi 0
	mov dx, COM1.IOBASE + COMx.ctrl_line
	outbi (1 shl 3) or (1 shl 2) or (3 shl 0) ; 8E2
	mov dx, COM1.IOBASE + COMx.intr_enable
	outbi 0 ; don't bother with interrupts for now
	mov dx, COM1.IOBASE + COMx.ctrl_fifo
	outbi 7 ; clear buffers and enable
	jmp .fin

.test:
	mov dx, COM1.IOBASE + COMx.ctrl_modem
	outbi 011011b ; DTR, DTS, OUT2 (IRQ), loop
	mov dx, COM1.IOBASE + COMx.tx
	outbi 'X'
	in al, dx
	cmp al, 'X'
	je .fin

.fail:
	mov rdx, [rsp]
	mov rcx, [rdx + EFI_SYSTEM_TABLE.ConOut]
	lea rdx, [com1_fail]
	call qword [rcx + EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL.OutputString]
@@:	hlt
	jmp @b


.fin:
	mov dx, COM1.IOBASE + COMx.ctrl_modem
	outbi 01011b ; DTR, DTS, OUT2 (IRQ)
	jmp .loop

	print com1_ok
	;jmp .halt

.loop:
	mov dx, COM1.IOBASE + COMx.tx
	outbi 0
	outbi 0
	outbi 0
	outbi 0
	outbi 0x55
	pause ; probably does nothing but...
	jmp .loop

.halt:
@@:	hlt
	jmp @b

hello_uefi: dw 'H', 'e', 'l', 'l', 'o', ' ', 'U', 'E', 'F', 'I', '!', 13, 10, 0
com1_init:  dw 'C', 'O', 'M', '1', ' ', 'i', 'n', 'i', 't', 13, 10, 0
com1_fail:  dw 'C', 'O', 'M', '1', ' ', 'f', 'a', 'i', 'l', 'u', 'r', 'e', 13, 10, 0
com1_ok:    dw 'C', 'O', 'M', '1', ' ', 'O', 'K', 13, 10, 0

times ((-$) and 0xfff) db 0

text_end:
