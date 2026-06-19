WADDLE_ROOTFS = https://dl-cdn.alpinelinux.org/alpine/v3.24/releases/x86_64/alpine-minirootfs-3.24.1-x86_64.tar.gz
CC   = cc
CURL = curl
TAR  = tar

all: build/waddle-rootfs/_done
	echo 'CONFIG.LIBOS.PATH equ "/out/libos/hello.bin"' > build/waddle-rootfs/config.inc
	./run-waddle.sh make x64-libos
	./run-waddle.sh make x64-uefi

clean:
	rm -rf build


build/waddle-rootfs/_done: | build/waddle-rootfs/ download/waddle-rootfs.tar.gz build/waddle
	$(TAR) -xf download/waddle-rootfs.tar.gz -C build/waddle-rootfs
	cp ./waddle/_init.sh build/waddle-rootfs/_init.sh
	./run-waddle.sh sh /_init.sh

build/waddle: waddle/waddle.c waddle/sys-x86_64.s waddle/sys.h waddle/util.h waddle/netlink.h | build/
	$(CC) -nostartfiles -nostdlib -static -Os waddle/waddle.c waddle/sys-x86_64.s -o $@

download/waddle-rootfs.tar.gz: | download/
	$(CURL) $(WADDLE_ROOTFS) -o $@

%/:
	mkdir -p $@
