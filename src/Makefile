O ?= ../build

x64-libos: $(O)/libos/
	fasm libos/x64/hello.asm $(O)/libos/hello.bin

x64-uefi:
	out=$(O)/uefi  sh boot/uefi/x64/build.sh

%/:
	mkdir -p $@
