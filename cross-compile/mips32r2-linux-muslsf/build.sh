#!/bin/sh
# One-touch build of the current committed checkout; no upstream checkout/fetch.
set -eu
TARGET_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(git -C "$TARGET_DIR" rev-parse --show-toplevel)
CACHE="$TARGET_DIR/.cache"

for command in git docker curl awk cp mktemp; do
    command -v "$command" >/dev/null 2>&1 || {
        printf 'Missing required command: %s\n' "$command" >&2
        exit 1
    }
done
if command -v sha256sum >/dev/null 2>&1; then
    checksum() { sha256sum "$1" | awk '{print $1}'; }
elif command -v shasum >/dev/null 2>&1; then
    checksum() { shasum -a 256 "$1" | awk '{print $1}'; }
else
    echo 'Install sha256sum or shasum before building' >&2
    exit 1
fi
if [ -n "$(git -C "$ROOT" status --porcelain --untracked-files=normal)" ]; then
    echo 'Working tree is not clean. Commit or stash changes before building.' >&2
    exit 1
fi
JOBS=${JOBS:-4}
case "$JOBS" in ''|0|*[!0-9]*) echo 'JOBS must be a positive integer' >&2; exit 1;; esac
docker buildx version >/dev/null
docker info >/dev/null

SOURCE_COMMIT=$(git -C "$ROOT" rev-parse HEAD)
SHORT_COMMIT=$(git -C "$ROOT" rev-parse --short=12 HEAD)
SOURCE_REF=$(git -C "$ROOT" symbolic-ref --short -q HEAD || \
    git -C "$ROOT" describe --tags --exact-match HEAD 2>/dev/null || printf 'detached')
VERSION=$(git -C "$ROOT" show "$SOURCE_COMMIT:wstunnel-cli/Cargo.toml" | \
    awk -F '"' '/^version = / {print $2; exit}')
case "$VERSION" in ''|*[!A-Za-z0-9._+-]*) echo 'Invalid or missing package version' >&2; exit 1;; esac

mkdir -p "$CACHE"
if ! mkdir "$CACHE/build.lock" 2>/dev/null; then
    echo "Another build holds $CACHE/build.lock (remove it only if no build is running)." >&2
    exit 1
fi
STAGE=''
TEMP_DOWNLOAD="$CACHE/toolchain.tgz.partial.$$"
cleanup() {
    [ -z "$STAGE" ] || rm -rf "$STAGE"
    rm -f "$TEMP_DOWNLOAD"
    rmdir "$CACHE/build.lock"
}
trap cleanup 0
trap 'exit 130' INT
trap 'exit 143' HUP TERM

EXPECTED=572476c458730f41c86e4db8ccd341ed1e66585897b214f282f2f05a445f47d3
if [ ! -f "$CACHE/toolchain.tgz" ]; then
    curl --fail --location --retry 3 --connect-timeout 30 \
        https://musl.cc/mips-linux-muslsf-cross.tgz -o "$TEMP_DOWNLOAD"
    [ "$(checksum "$TEMP_DOWNLOAD")" = "$EXPECTED" ] || {
        echo 'Downloaded cross-toolchain checksum does not match' >&2
        exit 1
    }
    mv "$TEMP_DOWNLOAD" "$CACHE/toolchain.tgz"
fi
[ "$(checksum "$CACHE/toolchain.tgz")" = "$EXPECTED" ] || {
    echo 'Cached cross-toolchain checksum does not match; remove it and retry' >&2
    exit 1
}
# git archive includes only the captured commit, never .git, ignored output,
# local credentials or uncommitted/untracked source files.
git -C "$ROOT" archive --format=tar "$SOURCE_COMMIT" > "$CACHE/source.tar"
SOURCE_ARCHIVE_SHA256=$(checksum "$CACHE/source.tar")
STAGE=$(mktemp -d "$CACHE/artifact.XXXXXX")
printf 'Building %s (%s), wstunnel %s, for big-endian MIPS32r2 soft-float\n' \
    "$SOURCE_REF" "$SOURCE_COMMIT" "$VERSION"
docker buildx build --platform linux/amd64 --progress plain --target artifact \
    --build-arg "SOURCE_COMMIT=$SOURCE_COMMIT" \
    --build-arg "SOURCE_REF=$SOURCE_REF" \
    --build-arg "SOURCE_ARCHIVE_SHA256=$SOURCE_ARCHIVE_SHA256" \
    --build-arg "BUILD_JOBS=$JOBS" \
    --output "type=local,dest=$STAGE" "$TARGET_DIR"

OUTPUT="$TARGET_DIR/output/$VERSION-$SHORT_COMMIT"
mkdir -p "$OUTPUT"
cp -R "$STAGE/." "$OUTPUT/"
printf '\nBuild complete: %s\n' "$OUTPUT"
printf 'Raw binary: %s/wstunnel_%s_linux_mips32r2_muslsf\n' "$OUTPUT" "$VERSION"
printf 'Release archive: %s/wstunnel_%s_linux_mips32r2_muslsf.tar.gz\n' "$OUTPUT" "$VERSION"
printf 'Source/build information: %s/BUILDINFO.txt\n' "$OUTPUT"
