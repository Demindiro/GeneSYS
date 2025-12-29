include "config.inc"

macro ifeq x, y, target {
	cmp x, y
	je target
}
macro ifne x, y, target {
	cmp x, y
	jne target
}

macro log.ok msg {
	push rsi
	lea rsi, [msg]
	call printmsg.ok
	pop rsi
}

use64

org bootloader.base_address

macro panic {
	cli
	hlt
}

	mov rax, cr3
	mov dword [page_root], eax

	call acpi_find_rsdp
	test esi, esi
	jz err_no_rsdp
	log.ok msg_ok_rsdp

	mov esi, [rsi + 16]
	cmp dword [rsi], "RSDT"
	jne err_no_rsdt
	log.ok msg_ok_rsdt

search_acpi_tables:
	mov ecx, [rsi + 4]
	sub ecx, 36
	shr ecx, 2
	add rsi, 36
@@:	lodsd
	mov eax, [eax]
	cmp eax, "MCFG"
	je .found_mcfg
	cmp eax, "APIC" ; yes, "MADT" has "APIC" as signature
	je .found_madt
	loop @b
	jmp .end
.found_mcfg:
	mov [acpi.mcfg], eax
	log.ok msg_ok_mcfg
	loop @b
.found_madt:
	mov [acpi.madt], eax
	log.ok msg_ok_madt
	loop @b
.end:


	call acpi.smp.init


	ifne dword [acpi.mcfg], 0, @f
	lea rsi, [msg_err_no_mcfg]
	call printmsg.warn
@@:

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
	push rax
@@:	xor eax, eax
	lock cmpxchg [console.lock], dl
	jne @b
	pop rax
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
	mov byte [console.lock], 0
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
msg ok_madt, "found MADT"

; this being 32-bits is very deliberate because
; the APs need to be able to read it from real mode
page_root: dd 0

acpi.mcfg: dd 0
acpi.madt: dd 0

console.lock: db 0
console.row: db 0

times (bootloader.required_size - ($ - bootloader.base_address)) db 0

assert $ = 0x10000
