IOAPIC.PHYS_BASE = 0xfec00000

virtual at 0xffffffffc03ff000
	ioapic.addr: dq ?, ?
	ioapic.data: dq ?, ?
end virtual

ioapic.init:
	mov dword [paging.pt_mmio.ioapic], IOAPIC.PHYS_BASE + PAGE.D + PAGE.A + PAGE.RW + PAGE.G + PAGE.P
	mov dword [ioapic.addr], 0x10 + 2*4
	mov dword [ioapic.data], 0x8040
	mov dword [ioapic.addr], 0x11 + 2*4
	mov dword [ioapic.data], 0
	ret
