# syntax=docker/dockerfile:1
# build.sh selects linux/amd64 for the musl.cc compiler's host architecture.
# The OUTPUT target is big-endian MIPS32r2, not amd64 or little-endian mipsel.
FROM debian:trixie-slim@sha256:a29215f6a35e51e22adffa17f89e9d2ef06214e64a2bad10d765c46aea49f11f AS toolchain
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl build-essential cmake clang libclang-dev pkg-config \
    file xz-utils qemu-user && rm -rf /var/lib/apt/lists/*
ENV RUSTUP_HOME=/opt/rustup CARGO_HOME=/opt/cargo
ENV PATH=/opt/cargo/bin:/opt/mips-linux-muslsf-cross/bin:$PATH
ARG RUST_TOOLCHAIN=nightly-2026-10-06
RUN curl --fail --location --retry 3 https://sh.rustup.rs -o /tmp/rustup.sh && \
    sh /tmp/rustup.sh -y --profile minimal --default-toolchain ${RUST_TOOLCHAIN} && \
    rustup component add rust-src && rm /tmp/rustup.sh
COPY .cache/toolchain.tgz /tmp/toolchain.tgz
RUN echo '572476c458730f41c86e4db8ccd341ed1e66585897b214f282f2f05a445f47d3  /tmp/toolchain.tgz' | sha256sum -c - && \
    tar -xzf /tmp/toolchain.tgz -C /opt && rm /tmp/toolchain.tgz && \
    mips-linux-muslsf-gcc --version && rustc -Vv
# Rust's static musl target asks for -lunwind. Supply GCC's genuine DWARF
# unwinder under that name: the same _Unwind_* ABI, not fake/stub functions.
RUN ln -s "$(mips-linux-muslsf-gcc -print-file-name=libgcc_eh.a)" \
    /opt/mips-linux-muslsf-cross/mips-linux-muslsf/lib/libunwind.a
ENV CARGO_TARGET_MIPS_UNKNOWN_LINUX_MUSL_LINKER=mips-linux-muslsf-gcc \
    CC_mips_unknown_linux_musl=mips-linux-muslsf-gcc \
    CXX_mips_unknown_linux_musl=mips-linux-muslsf-g++ \
    AR_mips_unknown_linux_musl=mips-linux-muslsf-ar \
    CFLAGS_mips_unknown_linux_musl="-march=mips32r2 -mabi=32 -msoft-float" \
    CXXFLAGS_mips_unknown_linux_musl="-march=mips32r2 -mabi=32 -msoft-float" \
    BINDGEN_EXTRA_CLANG_ARGS_mips_unknown_linux_musl="--target=mips-unknown-linux-musl --sysroot=/opt/mips-linux-muslsf-cross/mips-linux-muslsf -march=mips32r2 -mabi=32 -msoft-float" \
    CARGO_TARGET_MIPS_UNKNOWN_LINUX_MUSL_RUSTFLAGS="--cfg uuid_unstable -C target-cpu=mips32r2 -C target-feature=+crt-static -C link-self-contained=no -C link-arg=-msoft-float -C link-arg=-march=mips32r2 -C link-arg=-mabi=32"

FROM toolchain AS build
COPY .cache/source.tar /tmp/source.tar
ARG SOURCE_ARCHIVE_SHA256
RUN echo "${SOURCE_ARCHIVE_SHA256}  /tmp/source.tar" | sha256sum -c - && \
    mkdir /src && tar -xf /tmp/source.tar -C /src && rm /tmp/source.tar
WORKDIR /src
COPY build-in-container.sh /usr/local/bin/build-wstunnel
ARG SOURCE_COMMIT
ARG SOURCE_REF
ARG BUILD_JOBS=4
ENV CARGO_BUILD_JOBS=${BUILD_JOBS}
RUN --mount=type=cache,id=wstunnel-mips32r2-registry,target=/opt/cargo/registry \
    --mount=type=cache,id=wstunnel-mips32r2-target,target=/src/target \
    sh /usr/local/bin/build-wstunnel

FROM scratch AS artifact
COPY --from=build /out/ /
