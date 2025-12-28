; written before I remembered how much of a shitshow ACPI is,
; and especially AML.
;
; so fuck the RSDP, we'll hardcode an assumption on QEMU and
; be done with it.

acpi_find_rsdp:
	mov rax, "RSD PTR "
	mov esi, 0x40e
	movzx esi, word [rsi]
	shl esi, 4
	lea edi, [esi + 1024]
	call .find
	test esi, esi
	jnz .found
	mov esi, 0xe0000
	mov edi, 0x100000
.find:
@@:	cmp [rsi], rax
	je .found
	add esi, 16
	cmp esi, edi
	jne @b
	xor esi, esi
.found:
	ret

