ACPI.SMP.AP._STACK_BASE    = 1 shl 16
ACPI.SMP.AP._STACK_SIZE_P2 = 8

acpi.smp.init:
	mov esi, [acpi.madt]
	ifeq esi, 0, .no_madt
	mov esi, msg_init_smp
	call printmsg.info

	mov edi, LAPIC.BASE + LAPIC.icr
	mov dword [edi], LAPIC.ICR.DEST.ALL_EXCL_SELF or LAPIC.ICR.INIT or LAPIC.ICR.ASSERT
@@:	test dword edi, LAPIC.ICR.STATUS
	jnz @b
	mov dword [edi], LAPIC.ICR.DEST.ALL_EXCL_SELF or LAPIC.ICR.INIT
@@:	test dword edi, LAPIC.ICR.STATUS
	jnz @b
	mov dword [edi], LAPIC.ICR.DEST.ALL_EXCL_SELF or LAPIC.ICR.SIPI or LAPIC.ICR.ASSERT or (acpi.smp.boot16 shr 12)
	hlt

	ret

.no_madt:
	mov esi, msg_warn_no_madt
	jmp printmsg.warn


acpi.smp.ap._init:
	mov eax, 1
	cpuid
	shr ebx, 24
	inc ebx
	shl ebx, ACPI.SMP.AP._STACK_SIZE_P2
	lea esp, [ACPI.SMP.AP._STACK_BASE + ebx]
	log.ok msg_ap_started
	hlt


msg warn_no_madt, "no MADT found"
msg init_smp, "initializing SMP"
msg ap_started, "AP started"

use16
align 4096
acpi.smp.boot16:
	cli
	mov eax, dword [page_root]
    mov cr3, eax
    mov eax, 010100000b
    mov cr4, eax
    mov ecx, 0xc0000080
    rdmsr
    or ax, 0x100
    wrmsr
    mov ebx, cr0
    or ebx,0x80000001
    mov cr0, ebx
    lgdt [gdtr]
    jmp 0x10:acpi.smp.ap._init
use64
