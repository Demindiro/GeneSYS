; rsi: message address
; rcx: message length
;
; rax: bytes written
syslog.push:
	; limit log entries to at most 56 bytes
	mov eax, 56
	cmp rcx, rax
	cmova rcx, rax
	mov eax, ecx
	; ignore empty messages
	jrcxz .e
	rdtsc
	shr rdx, 32
	or rax, rdx
	shl rax, 16
	mov edi, [syslog.head]
	and edi, ((syslog.buffer.end - syslog.buffer) - 1) shr 6
	shl edi, 6
	mov edx, edi
	add rdi, syslog.buffer
	inc edx
	stosq
	rep movsb
	mov [syslog.head], edx
.e:	ret
