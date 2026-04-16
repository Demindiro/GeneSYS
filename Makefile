x64-libos: build/libos/
	out=$(PWD)/build/libos sh x64/libos/build.sh

x64-uefi:
	sh build.sh uefi

%/:
	mkdir -p $@
