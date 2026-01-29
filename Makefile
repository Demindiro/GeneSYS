x64-libos: build/libos/
	O=$(PWD)/build/libos make -C x64/libos

x64-uefi:
	sh build.sh uefi

x64-qemu:
	sh build.sh qemu

%/:
	mkdir -p $@
