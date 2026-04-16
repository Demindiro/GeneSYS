x64-libos: build/libos/
	O=$(PWD)/build/libos make -C x64/libos

x64-uefi:
	sh build.sh uefi

%/:
	mkdir -p $@
