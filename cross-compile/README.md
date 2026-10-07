# Cross-compiling wstunnel

Run the build script for your target from any directory. It compiles the
**current committed checkout**, using this repository's `Cargo.lock`; it does
not download a fixed upstream version or switch branches.

| Target | Hardware | Build command |
| --- | --- | --- |
| [mips32r2-linux-muslsf](mips32r2-linux-muslsf/) | Big-endian MIPS32r2, O32, soft-float; GL.iNet GL-AR300M / 24Kc | `./cross-compile/mips32r2-linux-muslsf/build.sh` |

Requirements: Git, Docker with a running daemon and buildx, curl, tar, and either
`sha256sum` or `shasum`. No host Rust installation is needed. Commit or stash
local changes first: builds require a clean working tree so each binary can be
traced to its source commit.

Each target keeps its Docker setup and script in its own directory. Generated
files stay in ignored `.cache/` and `output/` subdirectories. The script also
creates a release archive, a named raw binary, checksums and build information.

The setup was introduced on a branch based on upstream **v11.0.0**. The original
upstream tag is unchanged; custom releases use separate target-specific tags.
