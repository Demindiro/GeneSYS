DEBUG.RX.BUFFER_SIZE = 1 shl 10
DEBUG.TX.BUFFER_SIZE = 1 shl 10

if 0
debug.recv:
	ret

debug.send:
	hlt
	mov rsi, debug.tx.buffer
	movzx ecx, word [rsi]
	shr ecx, 6
	add ecx, 2
	call crc32c
	mov [debug.tx.crc], eax
	mov edx, COM1.IOBASE
	jmp comx.enable_tx_intr

debug.handle_tx:
	ret
end if

debug.handle_rx:
	movzx ecx, word [debug.rx.len]
.l:	mov edx, COM1.IOBASE
	comx.read_byte .e
	cmp cx, [debug.rx.cap]
	je .chunk_header
	mov [debug.rx.buffer + rcx], al
	inc ecx
	jmp .l
.chunk_header:
	test al, al
	jz .process_packet
	mov dl, [debug.rx.prev]
	mov [debug.rx.prev], al
	cmp dl, 0xfe
	seta dl
	sub al, dl
	add [debug.rx.cap], ax
	test dl, dl
	jnz .l
	mov byte [debug.rx.buffer + rcx], 0
	inc ecx
	jmp .l
.process_packet:
	; if the packet is 5 bytes or less (command ID + CRC32C),
	; we can't do anything with it so just discard
	sub ecx, 5
	jbe .f
	; TODO validate crc32
	mov rsi, debug.rx.buffer
	lodsb
	call qword [debug.commands + rax*8]
.f:	xor ecx, ecx
	mov byte [debug.rx.prev], 0xff
	mov word [debug.rx.cap], cx
.e:	mov word [debug.rx.len], cx
	ret

times ((-$) and 7) int3
debug.commands:
	dq debug.cmd_echo

debug.cmd_echo:
	ud2
	ret
