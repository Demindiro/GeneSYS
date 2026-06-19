x64-libos: build/libos/
	out=$(PWD)/build/libos sh libos/x64/build.sh

x64-uefi:
	out=$(PWD)/build/uefi  sh boot/uefi/x64/build.sh

%/:
	mkdir -p $@
