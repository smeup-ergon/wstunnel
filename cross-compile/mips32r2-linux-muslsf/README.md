# Big-endian MIPS32r2 / musl / soft-float

For MIPS 24Kc-class routers such as the GL.iNet GL-AR300M. The output is a static
32-bit **big-endian**, **O32**, **MIPS32r2 soft-float** executable. It is **not
compatible with little-endian `mipsel` devices**.

## One-touch build

From the repository root, on a clean committed branch or tag:

```sh
./cross-compile/mips32r2-linux-muslsf/build.sh
```

Requirements: Git, Docker with a running daemon and buildx, curl, tar, and
`sha256sum` or `shasum`. No host Rust/compiler installation is needed. The
builder runs as `linux/amd64` because the downloaded cross-compiler is x86_64;
Apple Silicon needs amd64 container support (tested with Docker Desktop).

The script snapshots **your current commit** with `git archive` and uses its
`Cargo.lock`. It does not fetch upstream, select v11.0.0, change your branch, or
include uncommitted changes. Commit or stash changes first. Builds download
approximately 100 MB of cross-toolchain plus Rust, Debian packages and crates;
allow several GB of Docker storage. Default parallelism is four jobs:

```sh
JOBS=2 ./cross-compile/mips32r2-linux-muslsf/build.sh
```

## Output

Files appear under `output/<package-version>-<commit>/` in this directory:

- `wstunnel`: executable ready to copy to the device.
- `wstunnel_<version>_linux_mips32r2_muslsf`: named raw release binary.
- `wstunnel_<version>_linux_mips32r2_muslsf.tar.gz`: executable, LICENSE, this
  README, build information and ELF/ABI reports.
- `SHA256SUMS`, `BUILDINFO.txt`, `elf-report.txt`, `abi-report.txt`.

Check downloaded release assets with `sha256sum -c SHA256SUMS` (or
`shasum -a 256 -c SHA256SUMS`) after extracting the archive into the same
folder as the named assets. Publish LICENSE alongside the raw binary; it is
also included in the archive. `.cache/` and `output/` are ignored by Git.

## What the container does

- Pins the Debian image digest, Rust `nightly-2026-10-06` and the musl.cc
  `mips-linux-muslsf` GCC 11.2.1 archive's SHA-256.
- Rebuilds Rust's standard library with `-Z build-std=std,panic_abort`, since
  MIPS is a Tier 3 target without official prebuilt Rust standard libraries.
- Keeps upstream source unchanged, the default AWS-LC TLS backend and protocol
  features. `aws-lc-rs-bindgen` generates MIPS bindings; it does not remove
  features. Optional jemalloc is not enabled (it is an allocator, not a protocol).
- Uses the compiler's musl startup files (`link-self-contained=no`, while
  retaining static linkage) and exposes its genuine GCC DWARF unwinder
  `libgcc_eh.a` as `libunwind.a`. **No fake unwind stubs or source patches.**
- Checks ELF architecture, soft-float ABI and absence of a dynamic loader, then
  runs version/client-help/server-help under QEMU's 24Kc CPU emulation.

The recipe is repeatable, not guaranteed byte-identical: Debian package feeds
and the rustup installer are not snapshot-pinned. The archive hash records
bytes obtained over HTTPS, not an independently verified vendor signature.
Keep the build information with published binaries. Future dependency/toolchain
changes may require updating this target's setup.

## Device validation and deployment

v11.0.0 was tested on a GL-AR300M (NOR), kernel-reported QCA9533 / MIPS 24Kc,
OpenWrt 22.03.4, Linux 5.10.176. TLS WebSocket TCP/UDP forwarding **and reverse
forwarding** passed without firmware changes. A 4 MiB TCP echo took about
7.4–8.8 seconds; RSS sampled after testing was about 9.5 MiB, not a peak-RAM
measurement. No real printer job or sustained-load benchmark was performed.

The binary is approximately **12.3 MiB**. Check free writable storage before
copying it: the tested NOR overlay had only 1.5 MiB free. `/tmp` can hold a
temporary test binary but consumes RAM and disappears on reboot. Static linking
does not guarantee compatibility with every firmware/kernel or embed CA roots.

TLS verification is disabled by upstream's CLI default. For deployment enable
`--tls-verify-certificate`, provide an appropriate CA store, and ensure correct
device time. The tested router's clock was in 2023; a backdated disposable
certificate was used only for the controlled test, not as a production solution.

The automatic build checks are smoke tests, not exhaustive CLI/protocol tests.
Separate QEMU tests passed for HTTP/2 and forward WebTransport. A combined
reverse-WebTransport fixture timed out and remains unverified; no feature was
removed to avoid it. Test your intended workload on the physical device.
