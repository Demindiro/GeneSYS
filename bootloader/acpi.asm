LAPIC.BASE = 0xfee00000
LAPIC.icr = 0x300

LAPIC.ICR.INIT = 0101b shl 8
LAPIC.ICR.SIPI = 0110b shl 8
LAPIC.ICR.ASSERT = 1 shl 14
LAPIC.ICR.STATUS = 1 shl 12
LAPIC.ICR.TRIGGER.EDGE  = 0 shl 15
LAPIC.ICR.TRIGGER.LEVEL = 1 shl 15
LAPIC.ICR.DEST.NO_SHORTHAND  = 000b shl 18
LAPIC.ICR.DEST.SELF          = 001b shl 18
LAPIC.ICR.DEST.ALL_INCL_SELF = 010b shl 18
LAPIC.ICR.DEST.ALL_EXCL_SELF = 011b shl 18

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


include "acpi/smp.asm"
