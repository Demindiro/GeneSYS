include "config.inc"

macro ifeq x, y, target {
	cmp x, y
	je target
}

use64

org bootloader.base_address

macro panic {
	cli
	hlt
}

	call acpi_find_rsdp
	test esi, esi
	jz err_no_rsdp
	push rsi
	lea rsi, [msg_ok_rsdp]
	call printmsg.ok
	pop rsi

	mov esi, [rsi + 16]
	cmp dword [rsi], "RSDT"
	jne err_no_rsdt
	push rsi
	lea rsi, [msg_ok_rsdt]
	call printmsg.ok
	pop rsi

search_mcfg:
	mov ecx, [rsi + 4]
	add rsi, 36
@@:	lodsd
	cmp dword [eax], "MCFG"
	je .found
	loop @b
	jnz .no_mcfg
.found:
	push rsi
	lea rsi, [msg_ok_mcfg]
	call printmsg.ok
	pop rsi

.no_mcfg:
	lea rsi, [msg_err_no_mcfg]
	call printmsg.warn

	call pci_scan

	hlt

	mov edx, 0x604
	mov eax, 0x2000
	out dx, ax
	hlt


err_no_rsdp:
	lea rsi, [msg_err_no_rsdp]
	jmp panicmsg
err_no_rsdt:
	lea rsi, [msg_err_no_rsdt]
	jmp panicmsg

panicmsg:
	mov ah, 4
	call printmsg
	panic

printmsg.warn:
	mov ah, 6
	jmp printmsg
printmsg.ok:
	mov ah, 2
	jmp printmsg
printmsg.info:
	mov ah, 7
	jmp printmsg
printmsg:
	push rcx
	movzx ecx, byte [rsi]
	inc esi
_print:
	push rdi
	push rdx
	mov edx, 160
	sub edx, ecx
	test ecx, ecx
	jz .e
	movzx edi, byte [console.row]
	imul edi, 160
	add edi, 0xb8000
.l:	lodsb
	stosw
	loop .l
.e:	inc byte [console.row]
	mov ecx, edx
	xor eax, eax
	rep stosw
	pop rdx
	pop rdi
	pop rcx
	ret


macro msg name, s {
	local end
	msg_#name: db end - $ - 1, s
	end:
}

include "bootloader/acpi.asm"
include "bootloader/pci.asm"

msg err_no_rsdp, "failed to find RSDP"
msg err_no_rsdt, "RSDP does not point to RSDT"
msg err_no_mcfg, "failed to find MCFG"
msg ok_rsdp, "found RSDP"
msg ok_rsdt, "found RSDT"
msg ok_mcfg, "found MCFG"

console.row: db 0

times (bootloader.required_size - ($ - bootloader.base_address)) db 0

assert $ = 0x10000
