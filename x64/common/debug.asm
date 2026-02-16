DEBUG.RX.BUFFER_SIZE = 1 shl 10
DEBUG.TX.BUFFER_SIZE = 1 shl 10

debug.init:
	; send a single zero byte to terminate previous data
	inc dword [debug.tx.head]
	mov edx, COM1.IOBASE
	jmp comx.enable_tx_intr

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
@@:	; check there is any data to write at all
	mov ecx, [debug.tx.tail]
	cmp ecx, [debug.tx.head]
	je comx.disable_tx_intr
	; only write if there is place in the buffer
	comx.jmp_if_write_full .e
	mov esi, ecx
	and esi, DEBUG.TX.BUFFER_SIZE - 1
	inc ecx
	mov [debug.tx.tail], ecx
	movzx eax, byte [debug.tx.buffer + rsi]
	comx.write_byte
	jmp @b
.e:	ret

times ((-$) and 7) int3
debug.commands:
	dq debug.cmd_echo
	dq debug.cmd_identify
	dq debug.cmd_syslog
	dq debug.cmd_message
DEBUG.COMMAND_MAX = ($ - debug.commands) / 8

debug.cmd_echo:
	sub rsp, 512
	mov rdi, rsp
	xor eax, eax
	stosb
	rep movsb
	mov ecx, edi
	sub ecx, esp
	mov rsi, rsp
	int3
	call debug.tx.send
	add rsp, 512
	ret

debug.cmd_identify:
	sub rsp, 64
	mov rdi, rsp
	mov rsi, .msg
	mov ecx, .msg_end - .msg
	rep movsb
	mov rsi, rsp
	mov ecx, .msg_end - .msg
	call debug.tx.send
	add rsp, 64
	ret
.msg: db 0, 0, 0, 0x64, 0x86, "GeneSYS 2026/02/13"
.msg_end:

debug.cmd_syslog:
	cmp rcx, 8
	jb .e
	lodsq
	call syslog.get_by_timestamp
	mov rdi, rsp
	test rsi, rsi
	jz .none
	sub rsp, 512
	mov  byte [rsp + 0], 0
	mov qword [rsp + 1], rax
	mov dword [rsp + 9], 0
	lea rdi, [rsp + 13]
	rep movsb
	mov ecx, edi
	sub ecx, esp
	mov rsi, rsp
	call debug.tx.send
	add rsp, 512
.e:	ret
.none:
	push 0
	mov rsi, rsp
	mov ecx, 1
	call debug.tx.send
	pop rax
	ret

debug.cmd_message:
	; avoid recursive debug message interrupts,
	; which easily could lead to a stack overflow
	mov eax, [libos.flags]
	bts eax, LIBOS.FLAGS.INTR_DEBUG_PENDING
	jc .e
	mov [libos.flags], eax
	call sysconf.push_frame
	mov rax, [rsi + SYSCALL.SYSCONF.INTERRUPT]
	mov qword [isr.rip], rax
	mov qword [isr.rax], LIBOS.INTR.DEBUG
.e:	ret

; rsi: message base
; rcx: message length
debug.event_syslog:
	sub rsp, 64
	mov rdi, rsp
	mov eax, 1
	stosw
	rep movsb
	mov ecx, edi
	sub ecx, esp
	mov rsi, rsp
	call debug.tx.send
	add rsp, 64
	ret

; rsi: data base. Must have 4 extra bytes at tail for CRC32C!
; rcx: data length
debug.tx.send:
	; append CRC32C
	push rsi
	lea rbx, [rsi + rcx + 4]
	call crc32c
	stosd
	pop rsi
	; COBS encode
	; We could do the encoding during transmission, i.e. zero-copy,
	; but it is very hard to get right (in assembly) as we need to look
	; up to 254 bytes ahead, then cache that knowledge.
	; Encoding beforehand requires 0.4% memory overhead but is much easier.
	mov ecx, [debug.tx.head]
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
	mov eax, edx
	sub eax, esi
	inc eax
	call .putbyte
	call .copybytes
	cmp rsi, rbx
	jne .l
	jmp .end
.partial:
	mov eax, edx
	sub eax, esi
	dec rdx
	call .putbyte
	call .copybytes
	inc rsi
	cmp rsi, rbx
	jne .l
.end:
	xor eax, eax
	call .putbyte
	mov [debug.tx.head], ecx
	mov edx, COM1.IOBASE
	jmp comx.enable_tx_intr

.putbyte:
	mov edi, ecx
	and edi, DEBUG.TX.BUFFER_SIZE - 1
	inc ecx
	mov [debug.tx.buffer + rdi], al
	ret
.copybytes:
	cmp rsi, rdx
	je .n
@@:	lodsb
	call .putbyte
	cmp rsi, rdx
	jne @b
.n:	ret
