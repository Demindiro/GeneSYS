IDT.IST.0     =  0 shl  0
IDT.IST.1     =  1 shl  0
IDT.IST.2     =  2 shl  0
IDT.IST.3     =  3 shl  0
IDT.GATE.INTR = 14 shl  8
IDT.GATE.TRAP = 15 shl  8
IDT.DPL.0     =  0 shl 13
IDT.DPL.3     =  3 shl 13
IDT.P         =  1 shl 15

x = 0
macro f nr, target {
	assert nr = x
	x = x + 1
	dw (target shr  0) and 0xffff
	dw 0
	dw 0
	dw (target shr 16) and 0xffff
	dd (target shr 32) and 0xffffffff
	dd 0
}
align 64
idt:
f   0, idt.ex_dt
f   1, idt.ex_db
f   2, idt.ex_nmi
f   3, idt.ex_bp
f   4, idt.ex_of
f   5, idt.ex_br
f   6, idt.ex_ud
f   7, idt.ex_nm
f   8, idt.ex_df
f   9, idt.ex_reserved
f  10, idt.ex_ts
f  11, idt.ex_np
f  12, idt.ex_ss
f  13, idt.ex_gp
f  14, idt.ex_pf
f  15, idt.ex_reserved
f  16, idt.ex_mf
f  17, idt.ex_ac
f  18, idt.ex_mc
f  19, idt.ex_xm
f  20, idt.ex_ve
f  21, idt.ex_cp
f  22, idt.ex_reserved
f  23, idt.ex_reserved
f  24, idt.ex_reserved
f  25, idt.ex_reserved
f  26, idt.ex_reserved
f  27, idt.ex_reserved
f  28, idt.ex_hv
f  29, idt.ex_vc
f  30, idt.ex_sx
f  31, idt.ex_reserved
repeat 256 - 32 - 1
	f (32 + (% - 1)), idt.intr_unmapped
end repeat
f 255, idt.intr_com1
.end: assert x = 256
purge f, x


idt.ex_reserved:
	hlt

idt.ex_dt:
	hlt
idt.ex_db:
	hlt
idt.ex_nmi:
	hlt
idt.ex_bp:
	hlt
idt.ex_of:
	hlt
idt.ex_br:
	hlt
idt.ex_ud:
	hlt
idt.ex_nm:
	hlt
idt.ex_df:
	hlt
idt.ex_ts:
	hlt
idt.ex_np:
	hlt
idt.ex_ss:
	hlt
idt.ex_gp:
	hlt
idt.ex_pf:
	hlt
idt.ex_mf:
	hlt
idt.ex_ac:
	hlt
idt.ex_mc:
	hlt
idt.ex_xm:
	hlt
idt.ex_ve:
	hlt
idt.ex_cp:
	hlt
idt.ex_hv:
	hlt
idt.ex_vc:
	hlt
idt.ex_sx:
	hlt

idt.intr_unmapped:
	iretq

idt.intr_com1:
	hlt
