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
	test al, al
	jz .process_packet
	cmp cx, [debug.rx.cap]
	je .chunk_header
	mov [debug.rx.buffer + rcx], al
	inc ecx
	jmp .l
.chunk_header:
	movzx edx, byte [debug.rx.prev]
	mov [debug.rx.prev], al
	cmp dl, 0xff
	je @f
	mov byte [debug.rx.buffer + rcx], 0
	inc ecx
	add [debug.rx.cap], ax
	jmp .l
@@:	dec eax
	add [debug.rx.cap], ax
	jmp .l
.process_packet:
	; if the packet is less than 5 bytes (command ID + CRC32C),
	; we can't do anything with it so just discard
	cmp ecx, 5
	jb .f
	; validate CRC
	mov rsi, debug.rx.buffer
	mov ebx, ecx
	call crc32c
	cmp eax, crc32c.VALIDATE
	jne .f
	; get command ID
	movzx eax, byte [debug.rx.buffer]
	; don't call invalid commands
	cmp al, DEBUG.COMMAND_MAX - 1
	ja .f
	lea ecx, [ebx - 5]
	mov rsi, debug.rx.buffer + 1
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
DEBUG.COMMAND_MAX = ($ - debug.commands) / 8

debug.cmd_echo:
	mov rdi, debug.tx.buffer
	mov ebx, ecx
	xor eax, eax
	stosb
	rep movsb
	lea ecx, [ebx + 1]
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
@@:	movzx eax, byte [rdx]
	inc rdx
	test eax, eax
	jz .partial
	mov eax, edx
	sub eax, esi
	cmp eax, 0xfe
	jae .full
	cmp rdx, rbx
	jne @b
.full:
	mov ecx, edx
	sub ecx, esi
	lea eax, [ecx + 1]
	stosb
	rep movsb
	cmp rsi, rbx
	jne .l
	jmp .end
.partial:
	mov ecx, edx
	sub ecx, esi
	mov [rdi], cl
	dec ecx
	inc rdi
	rep movsb
	inc rsi
	cmp rsi, rbx
	jne .l
.end:
	xor eax, eax
	stosb
	mov word [debug.tx.cur], -8
	mov edx, COM1.IOBASE
	jmp comx.enable_tx_intr
