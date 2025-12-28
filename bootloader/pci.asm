PCI_IO_CONFIG_ADDRESS = 0xcf8
PCI_IO_CONFIG_DATA    = 0xcfc

PCI_HDR_BAR.0 = 0x10

PCI_CLASS_SCSI    = 0x01000000
PCI_CLASS_IDE_ISA = 0x01018000

pci_scan:
	mov ebx, (1 shl 31) or 0
	mov dx, PCI_IO_CONFIG_ADDRESS
@@:	call .get_id
	cmp eax, -1
	jne .functions
	add ebx, 256 * 8
.n:	cmp ebx, (1 shl 31) or (256 * 256)
	jne @b
	ret

.functions:
	mov ecx, 8
	mov r8, rax
	jmp .analyze
@@:	add ebx, 256
	call .get_id
	mov r8, rax
	cmp eax, -1
	jne .analyze
.m:	loop @b
	add ebx, 256
	jmp .n

.analyze:
	push rdx
	call .get_class
	mov al, 0
	ifeq eax, PCI_CLASS_SCSI, pci.init.scsi
	ifeq eax, PCI_CLASS_IDE_ISA, pci.init.ide_isa
.o:	pop rdx
	jmp .m


.get_id:
	mov eax, ebx
	jmp .read
.get_class:
	lea eax, [ebx + 8]
	jmp .read
.get_capability:
	lea eax, [ebx + 0x34]
	jmp .read
.read:
	mov edx, PCI_IO_CONFIG_ADDRESS
	out dx, eax
	push rdx
	add edx, 4
	in eax, dx
	pop rdx
	ret
.write:
	mov edx, PCI_IO_CONFIG_ADDRESS
	out dx, eax
	push rdx
	add edx, 4
	mov eax, ecx
	out dx, eax
	pop rdx
	ret

pci.init.scsi:
	ifeq r8, 0x10011af4, pci.init.scsi.virtio_blk
	lea rsi, [msg_found_scsi]
	call printmsg.info
	jmp pci_scan.o

pci.init.scsi.virtio_blk:
	lea rsi, [msg_found_virtio_blk]
	call printmsg.info
	mov ecx, 6
	lea eax, [ebx + 0x4]
	call pci_scan.write
	jmp pci_virtio.blk.init

pci.init.ide_isa:
	lea rsi, [msg_found_ide_isa]
	call printmsg.info
	jmp pci_scan.o

include "pci/virtio.asm"

msg found_virtio_blk, "found virtio-blk"
msg found_scsi, "found SCSI (unknown)"
msg found_ide_isa, "found IDE (ISA)"
