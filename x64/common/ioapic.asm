IOAPIC.PHYS_BASE = 0xfec00000

virtual at 0xffffffffc03ff000
	ioapic.addr: dq ?, ?
	ioapic.data: dq ?, ?
end virtual

ioapic.init:
	; disable 8259 PIC
	mov al, 0xff
	out 0x21, al
	out 0xa1, al
	; make PIT shut up so QEMU doesn't spam trace
	mov al, 0x30
	out 0x43, al
	; map IOAPIC
	mov dword [paging.pt_mmio.ioapic], IOAPIC.PHYS_BASE + PAGE.D + PAGE.A + PAGE.RW + PAGE.G + PAGE.P
	; enable COM1
	mov dword [ioapic.addr], 0x10 + 2*4
	mov dword [ioapic.data], 0x80f8
	mov dword [ioapic.addr], 0x11 + 2*4
	mov dword [ioapic.data], 0
	ret
