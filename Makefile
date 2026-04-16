x64-libos: build/libos/
	out=$(PWD)/build/libos sh x64/libos/build.sh

x64-uefi:
	out=$(PWD)/build/uefi  sh x64/uefi/build.sh

%/:
	mkdir -p $@
