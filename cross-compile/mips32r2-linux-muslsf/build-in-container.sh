#!/bin/sh
set -eu
: "${SOURCE_COMMIT:?build.sh must supply the source commit}"
: "${SOURCE_REF:?build.sh must supply the checkout reference}"
: "${SOURCE_ARCHIVE_SHA256:?build.sh must supply the source archive checksum}"

# Keep the default AWS-LC TLS provider and all protocol functionality.
# bindgen only generates the native bindings for this Tier 3 target.
cargo build --locked --release -p wstunnel-cli --bin wstunnel \
    --features aws-lc-rs-bindgen --target mips-unknown-linux-musl \
    -Z build-std=std,panic_abort

mkdir /out
cp target/mips-unknown-linux-musl/release/wstunnel /out/wstunnel
cp LICENSE /out/LICENSE
cp cross-compile/mips32r2-linux-muslsf/README.md /out/README.md
file /out/wstunnel
mips-linux-muslsf-readelf -h -l -d /out/wstunnel > /out/elf-report.txt
mips-linux-muslsf-readelf -A /out/wstunnel > /out/abi-report.txt
# Fail rather than exporting an executable with the wrong CPU/ABI or loader.
grep -q 'Class:.*ELF32' /out/elf-report.txt
grep -q 'Data:.*big endian' /out/elf-report.txt
grep -q 'Flags:.*o32.*mips32r2' /out/elf-report.txt
grep -q 'FP ABI: Soft float' /out/abi-report.txt
if grep -q 'INTERP\|NEEDED' /out/elf-report.txt; then
    echo 'Expected a statically linked executable without a dynamic loader' >&2
    exit 1
fi

version=$(awk -F '"' '/^version = / {print $2; exit}' wstunnel-cli/Cargo.toml)
actual=$(qemu-mips -cpu 24Kc /out/wstunnel --version)
[ "$actual" = "wstunnel-cli $version" ]
printf '%s\n' "$actual"
qemu-mips -cpu 24Kc /out/wstunnel client --help >/dev/null
qemu-mips -cpu 24Kc /out/wstunnel server --help >/dev/null

{
    printf 'source_commit=%s\nsource_ref=%s\n' "$SOURCE_COMMIT" "$SOURCE_REF"
    printf 'source_archive_sha256=%s\n' "$SOURCE_ARCHIVE_SHA256"
    printf 'target=mips-unknown-linux-musl\ncpu=mips32r2\nabi=o32,soft-float,big-endian\n'
    printf 'version=%s\nfeatures=default,aws-lc-rs-bindgen\n' "$version"
    printf 'toolchain_archive_sha256=572476c458730f41c86e4db8ccd341ed1e66585897b214f282f2f05a445f47d3\n'
    printf 'size_bytes=%s\n' "$(stat -c '%s' /out/wstunnel)"
    rustc -Vv
    cargo -V
    mips-linux-muslsf-gcc --version
    printf 'checks=ELF/ABI/static-linkage; QEMU 24Kc version/client-help/server-help\n'
} > /out/BUILDINFO.txt

asset="wstunnel_${version}_linux_mips32r2_muslsf"
cd /out
cp wstunnel "$asset"
tar -czf "$asset.tar.gz" wstunnel LICENSE README.md BUILDINFO.txt elf-report.txt abi-report.txt
sha256sum wstunnel "$asset" "$asset.tar.gz" LICENSE README.md BUILDINFO.txt \
    elf-report.txt abi-report.txt > SHA256SUMS
