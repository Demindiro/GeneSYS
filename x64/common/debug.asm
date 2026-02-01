DEBUG.RX.BUFFER_SIZE = 1 shl 10
DEBUG.TX.BUFFER_SIZE = 1 shl 10

debug.init:
	mov word [debug.tx.cur], DEBUG.TX.BUFFER_SIZE
	ret

debug.handle:
	; fall through to debug.handle_rx

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
	; if the packet is less than 5 bytes (command ID + CRC32C),
	; we can't do anything with it so just discard
	sub ecx, 5
	jb .f
	; TODO validate crc32
	mov rsi, debug.rx.buffer
	lodsb
	call qword [debug.commands + rax*8]
.f:	xor ecx, ecx
	mov byte [debug.rx.prev], 0xff
	mov word [debug.rx.cap], cx
.e:	mov word [debug.rx.len], cx
	; fall through to debug.handle_tx

debug.handle_tx:
	mov edx, COM1.IOBASE
	movsx rsi, word [debug.tx.cur]  ; signed!!
	cmp si, DEBUG.TX.BUFFER_SIZE
	je comx.disable_tx_intr
	add rsi, debug.tx.buffer
	; just in case of spurious/shared interrupt
@@:	comx.jmp_if_write_full .e
	lodsb
	comx.write_byte
	test al, al
	jnz @b
	mov word [debug.tx.cur], DEBUG.TX.BUFFER_SIZE
	jmp comx.disable_tx_intr
.e:	sub si, debug.tx.buffer and 0xffff
	mov [debug.tx.cur], si
	ret

times ((-$) and 7) int3
debug.commands:
	dq debug.cmd_echo

debug.cmd_echo:
	mov rdi, debug.tx.buffer
	mov ebx, ecx
	rep movsb
	mov ecx, ebx
	jmp debug.tx.send

; debug.tx.buffer: data base
; rcx: length
debug.tx.send:
	; append CRC32C
	mov rsi, debug.tx.buffer
	lea rbx, [rsi + rcx + 4]
	call crc32c
	stosd
	; COBS encode
	; We could do the encoding during transmission, i.e. zero-copy,
	; but it is very hard to get right (in assembly) as we need to look
	; up to 254 bytes ahead, then cache that knowledge.
	; Encoding beforehand requires 0.4% memory overhead but is much easier.
	mov rdi, debug.tx.buffer.extra
	mov rsi, debug.tx.buffer
.l:	mov rdx, rsi
@@:	cmp rdx, rbx
	jz .e
	movzx eax, byte [rdx]
	inc rdx
	test al, al
	jnz @b
	mov eax, edx
	sub eax, esi
	stosb
	mov ecx, eax
	dec ecx
	rep movsb
	inc rsi
	cmp rsi, rbx
	jnz .l
.e:	mov eax, edx
	sub eax, esi
	mov ecx, eax
	inc eax
	stosb
	rep movsb
	xor eax, eax
	stosb
	mov word [debug.tx.cur], -8
	mov edx, COM1.IOBASE
	jmp comx.enable_tx_intr
