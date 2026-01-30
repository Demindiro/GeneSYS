KERNEL.CODE.START = 0xffffffffc0000000
KERNEL.CODE.END   = KERNEL.CODE.START + (1 shl 21)
KERNEL.DATA.START = KERNEL.CODE.START + (7 shl 21)
KERNEL.DATA.END   = KERNEL.DATA.START + (1 shl 21)

BOOTINFO.sizeof       = 48
BOOTINFO.phys_base    =  0
BOOTINFO.init_pagetable =  8
BOOTINFO.memmap.start = 16
BOOTINFO.memmap.end   = 24
BOOTINFO.libos.start  = 32
BOOTINFO.libos.end    = 40
