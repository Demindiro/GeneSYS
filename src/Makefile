O = ../build

x64-libos: $(O)/libos/
	out=$(PWD)/$(O)/libos sh libos/x64/build.sh

x64-uefi:
	out=$(PWD)/$(O)/uefi  sh boot/uefi/x64/build.sh

%/:
	mkdir -p $@
