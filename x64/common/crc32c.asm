; rsi: data base
; rcx: data len (in bytes)
;
; eax: result
; ecx, edx: clobber
; rsi, rdi: data end
crc32c:
.POLY = 0x82f63b78
	mov eax, -1
	jrcxz .e
	lea rdi, [rsi + rcx]
.l:	xor al, byte [rsi]
	inc rsi
	mov ecx, 8
@@:	mov edx, eax
	and edx, 1
	neg edx
	and edx, .POLY
	shr eax, 1
	xor eax, edx
	loop @b
	cmp rdi, rsi
	jne .l
.e:	not eax
	ret


if 0
crc32c_test:
; https://stackoverflow.com/a/20965225
.input: db "123456789"
.output: dd 0xe3069283
; https://www.rfc-editor.org/rfc/rfc3720#appendix-B.4
.input2: times 32 db 0
.output2: dd 0x8a9136aa
end if
