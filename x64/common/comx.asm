COM1.IOBASE = 0x3f8
COM2.IOBASE = 0x2f8

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

COMx.STAT_LINE.DR   = 1 shl 0
COMx.STAT_LINE.THRE = 1 shl 5

COMx.INTR.RX_AVAIL     = 1 shl 0
COMx.INTR.TX_EMPTY     = 1 shl 1
COMx.INTR.RX_STATUS    = 1 shl 2
COMx.INTR.MODEM_STATUS = 1 shl 3

; rdx: I/O base
;
; rdx: I/O base
; rax: clobbered
comx.init:
x = 0
macro f reg, val {
	;mov edx, COM1.IOBASE + reg
	add edx, reg - x
	x = reg
	mov al, val
	out dx, al
}
	f COMx.ctrl_line, 1 shl 7
	f COMx.baud_lo, 1 ; 115200
	f COMx.baud_hi, 0
	f COMx.ctrl_line, 0x03 ; 1 byte, 8N1
	f COMx.intr_enable, COMx.INTR.RX_AVAIL
	f COMx.ctrl_fifo, 7 ; clear buffers and enable
	f COMx.ctrl_modem, 01011b ; DTR, DTS, OUT2 (IRQ)
	add edx, -x
purge f, x
	ret

if 0
macro outbi val {
	mov al, val
	out dx, al
}

comx.test:
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
end if

; rsi: data base
; rcx: data len
; rdx: I/O base
;
; rsi: remaining data base
; rcx: remaining data len
; rdx: I/O base
; rax: clobbered
comx.write:
	jrcxz .e
.l:	call comx._stat_line
	test al, COMx.STAT_LINE.THRE
	jz .e
	lodsb
	out dx, al
	loop .l
.e:	ret

; rdi: buffer base
; rcx: buffer len
; rdx: I/O base
;
; rdi: remaining buffer base
; rcx: remaining buffer len
; rdx: I/O base
; rax: clobbered
comx.read:
	jrcxz .e
.l:	call comx._stat_line
	test al, COMx.STAT_LINE.DR
	jz .e
	in al, dx
	stosb
	loop .l
.e:	ret

; rdx: I/O base
;
; rax: byte
; rdx: I/O base
macro comx.read_byte target_ifnone {
	call comx._stat_line
	test al, COMx.STAT_LINE.DR
	jz target_ifnone
	xor eax, eax
	in al, dx
}

; rdx: I/O base
;
; rdx: I/O base
; al: status
comx._stat_line:
	add edx, COMx.stat_line
	in al, dx
	sub edx, COMx.stat_line
	ret
