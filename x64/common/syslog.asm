SYSLOG.BUFFER_SIZE = 1 shl 17

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

; get the first message at or after the given timestamp
;
; rax: timestamp
;
; rax: timestamp
; rsi: message base if some, or zero if none
; rcx: message length
syslog.get_by_timestamp:
	mov ecx, [syslog.head]
	mov rsi, syslog.buffer
	shl ecx, 6
	mov ebx, ecx
.scan:
	mov rdx, [rsi + rcx]
	cmp rdx, rax
	jae .found
	add ecx, 64
	and ecx, SYSLOG.BUFFER_SIZE - 1
	cmp ecx, ebx
	jne .scan
	xor esi, esi
	ret
.found:
	mov rax, rdx
	add rsi, rcx
	lea rcx, [rsi + 63]
	add rsi, 8
	; look for last non-zero byte
@@:	cmp byte [rcx], 0
	jne .e
	dec rcx
	cmp rcx, rsi
	jae @b
.e:	sub ecx, esi
	inc ecx
	ret
