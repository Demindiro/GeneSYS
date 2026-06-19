set -xe

apk add rustup curl make mtools util-linux-misc build-base || true

rustup-init --default-toolchain none -y
cat <<EOF > /root/.cargo/config.toml
[build]
target-dir = "/out/rust"
EOF

curl -sL https://flatassembler.net/fasm-1.73.31.tgz | tar -xz -C /usr/local
ln -s /usr/local/fasm/fasm /usr/local/bin/fasm

touch /_done
