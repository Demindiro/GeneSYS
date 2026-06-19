set -xe
apk add curl make mtools util-linux-misc || true
curl -sL https://flatassembler.net/fasm-1.73.31.tgz | tar -xz -C /usr/local
ln -s /usr/local/fasm/fasm /usr/local/bin/fasm
curl --proto '=https' -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain none
touch /_done
