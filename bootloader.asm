use64

org bootloader_base_address

mov edi, 0xb8000
mov ax, 'a' or (0x7 shl 8)
mov ecx, 2000
rep stosw
hlt

mov edx, 0x604
mov eax, 0x2000
out dx, ax
hlt

times (bootloader_required_size - ($ - bootloader_base_address)) db 0

assert $ = 0x10000
