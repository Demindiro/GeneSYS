#!/bin/sh
mkdir -p build/out
cp /etc/resolv.conf build/waddle-rootfs/etc/
exec env -i \
	HOME=/root \
	PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/root/.cargo/bin \
	O=/out \
	./build/waddle \
	--base build/waddle-rootfs \
	--bind /dev /dev \
	--bind /src src \
	--bind /out build/out \
	--net \
	--mount-proc \
	--cwd /src \
	-- \
	"$@"
