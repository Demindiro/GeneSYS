VIRTIO_PCI_CAP_COMMON_CFG  = 1 
VIRTIO_PCI_CAP_NOTIFY_CFG  = 2 
VIRTIO_PCI_CAP_ISR_CFG     = 3 
VIRTIO_PCI_CAP_DEVICE_CFG  = 4 
VIRTIO_PCI_CAP_PCI_CFG     = 5

VIRTIO_PCI_COMMON_CFG.device_feature_select =  0
VIRTIO_PCI_COMMON_CFG.device_feature        =  4
VIRTIO_PCI_COMMON_CFG.driver_feature_select =  8
VIRTIO_PCI_COMMON_CFG.driver_feature        = 12
VIRTIO_PCI_COMMON_CFG.msix_config           = 16
VIRTIO_PCI_COMMON_CFG.num_queues            = 18
VIRTIO_PCI_COMMON_CFG.device_status         = 20
VIRTIO_PCI_COMMON_CFG.config_generation     = 21
VIRTIO_PCI_COMMON_CFG.queue_select          = 22
VIRTIO_PCI_COMMON_CFG.queue_size            = 24
VIRTIO_PCI_COMMON_CFG.queue_msix_vector     = 26
VIRTIO_PCI_COMMON_CFG.queue_enable          = 28
VIRTIO_PCI_COMMON_CFG.queue_notify_off      = 30
VIRTIO_PCI_COMMON_CFG.queue_desc            = 32
VIRTIO_PCI_COMMON_CFG.queue_avail           = 40
VIRTIO_PCI_COMMON_CFG.queue_used            = 48
VIRTIO_PCI_COMMON_CFG.sizeof                = 56

VIRTIO_DEVICE_STATUS.ACKNOWLEDGE = 1 shl 0
VIRTIO_DEVICE_STATUS.DRIVER      = 1 shl 1
VIRTIO_DEVICE_STATUS.DRIVER_OK   = 1 shl 2
VIRTIO_DEVICE_STATUS.FEATURES_OK = 1 shl 3

VIRTQ_DESC.addr   = 0
VIRTQ_DESC.len    = 8
VIRTQ_DESC.flags  = 12
VIRTQ_DESC.next   = 14
VIRTQ_DESC.sizeof = 16
VIRTQ_DESC_F.NEXT     = 1 shl 0
VIRTQ_DESC_F.WRITE    = 1 shl 1
VIRTQ_DESC_F.INDIRECT = 1 shl 2

VIRTIO.BLK.T_IN    = 0
VIRTIO.BLK.T_OUT   = 1
VIRTIO.BLK.T_FLUSH = 4


BLKTEST.DESC  = (1 shl 20) or (0 shl 12)
BLKTEST.AVAIL = (1 shl 20) or (1 shl 12)
BLKTEST.USED  = (1 shl 20) or (2 shl 12)
BLKTEST.DATA  = (1 shl 20) or (3 shl 12)

pci_virtio.blk.init:
	sub esp, 16*8
	mov edi, esp
	call pci_virtio.init
	call pci_virtio.init_queues
	mov eax, esp
	call pci_virtio.blk.test
	mov eax, BLKTEST.DATA
	hlt
	add esp, 16*8
	jmp pci_scan.o

pci_virtio.blk.test:
	mov edi, BLKTEST.DESC
	mov esi, BLKTEST.DATA + 1024
	mov qword [rsi + 0], VIRTIO.BLK.T_IN
	mov qword [rsi + 8], 0
	mov qword [rdi +  0 + VIRTQ_DESC.addr ], rsi
	mov dword [rdi +  0 + VIRTQ_DESC.len  ], 16
	mov  word [rdi +  0 + VIRTQ_DESC.flags], VIRTQ_DESC_F.NEXT
	mov  word [rdi +  0 + VIRTQ_DESC.next ], 1
	mov qword [rdi + 16 + VIRTQ_DESC.addr ], BLKTEST.DATA + 0
	mov dword [rdi + 16 + VIRTQ_DESC.len  ], 1024
	mov  word [rdi + 16 + VIRTQ_DESC.flags], VIRTQ_DESC_F.WRITE or VIRTQ_DESC_F.NEXT
	mov  word [rdi + 16 + VIRTQ_DESC.next ], 2
	mov qword [rdi + 32 + VIRTQ_DESC.addr ], BLKTEST.DATA + 1024 + 32
	mov dword [rdi + 32 + VIRTQ_DESC.len  ], 1
	mov  word [rdi + 32 + VIRTQ_DESC.flags], VIRTQ_DESC_F.WRITE
	mov  word [rdi + 32 + VIRTQ_DESC.next ], 0

	mov edi, BLKTEST.AVAIL
	mov word [edi + 4], 0
	mov word [edi + 2], 1

	mov edi, eax
	mov esi, VIRTIO_PCI_CAP_NOTIFY_CFG*16
	call pci_virtio.read_bar
	mov word [rax], 0
	ret


pci_virtio.init:
	push rdi
	mov ecx, 16
	rep stosq
	call pci_scan.get_capability
.loop:
	mov ecx, eax
	lea esi, [ecx + 12]
	add eax, ebx
	call pci_scan.read
	mov edi, eax
	shr edi, 24
	shl edi, 4
	add edi, [rsp]
	stosd
@@:	add ecx, 4
	lea eax, [ebx + ecx]
	call pci_scan.read
	stosd
	cmp ecx, esi
	jne @b
	movzx eax, byte [rdi - 16 + 1]
	test eax, eax
	jnz .loop
	pop rdi
	ret

pci_virtio.init_queues:
	mov esi, VIRTIO_PCI_CAP_COMMON_CFG * 16
	call pci_virtio.read_bar
	lea esi, [eax + VIRTIO_PCI_COMMON_CFG.device_status]
	; reset
	mov byte [rsi], 0
@@:	cmp byte [rsi], 0
	jnz @b
	; acknowledge
	mov byte [rsi], VIRTIO_DEVICE_STATUS.ACKNOWLEDGE or VIRTIO_DEVICE_STATUS.DRIVER
	; don't negotiate any features
	mov dword [rax + VIRTIO_PCI_COMMON_CFG.driver_feature_select], 0
	mov dword [rax + VIRTIO_PCI_COMMON_CFG.driver_feature], 0
	mov dword [rax + VIRTIO_PCI_COMMON_CFG.driver_feature_select], 1
	mov dword [rax + VIRTIO_PCI_COMMON_CFG.driver_feature], 0
	mov byte [rsi], VIRTIO_DEVICE_STATUS.ACKNOWLEDGE or VIRTIO_DEVICE_STATUS.DRIVER or VIRTIO_DEVICE_STATUS.FEATURES_OK
	; shouldn't be possible, but...
	mov dl, [rsi]
	test dl, VIRTIO_DEVICE_STATUS.FEATURES_OK
	jz pci_virtio.unsupported_features

	; TODO device-type-specific
	; virtio-blk requestq init (0)
	mov word [rax + VIRTIO_PCI_COMMON_CFG.queue_select], 0
	mov word [rax + VIRTIO_PCI_COMMON_CFG.queue_size], 4
	mov word [rax + VIRTIO_PCI_COMMON_CFG.queue_msix_vector], 0xffff
	movzx r8, word [rax + VIRTIO_PCI_COMMON_CFG.queue_notify_off]
	mov qword [rax + VIRTIO_PCI_COMMON_CFG.queue_desc ], BLKTEST.DESC
	mov qword [rax + VIRTIO_PCI_COMMON_CFG.queue_avail], BLKTEST.AVAIL
	mov qword [rax + VIRTIO_PCI_COMMON_CFG.queue_used ], BLKTEST.USED
	mov edi, BLKTEST.DESC
	mov qword [rdi], 0
	mov edi, BLKTEST.AVAIL
	mov qword [rdi], 0
	mov edi, BLKTEST.USED
	mov qword [rdi], 0
	mov word [rax + VIRTIO_PCI_COMMON_CFG.queue_enable], 1

	; start device
	mov byte [rsi], VIRTIO_DEVICE_STATUS.ACKNOWLEDGE or VIRTIO_DEVICE_STATUS.DRIVER or VIRTIO_DEVICE_STATUS.FEATURES_OK or VIRTIO_DEVICE_STATUS.DRIVER_OK
	ret


; edi: capability array
; esi: capability type multiplied by 16
;
; rax: base address
pci_virtio.read_bar:
	push rsi
	mov esi, [rdi + rsi + 4]
	lea esi, [ebx + PCI_HDR_BAR.0 + esi * 4]
	mov eax, esi
	call pci_scan.read
	test eax, 1
	jnz pci_virtio.io_space_unsupported
	test eax, 4
	jz .bar32
.bar64:
	and eax, not 15
	push rax
	lea eax, [esi + 4]
	call pci_scan.read
	pop rdx
	shl rax, 32
	or rax, rdx
.bar32:
	pop rsi
	mov ecx, [rdi + rsi + 8]
	add rax, rcx
	ret


; TODO display proper error
pci_virtio.io_space_unsupported:
	hlt

; TODO display proper error
pci_virtio.unsupported_features:
	hlt
