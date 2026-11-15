#!/usr/bin/env bash
set -euo pipefail

project_dir=$(cd -- "$(dirname -- "$0")/.." && pwd)
# shellcheck source=sources.env
source "$project_dir/sources.env"
build_dir=$(realpath -m -- "$project_dir/build")
dist_dir="$project_dir/dist"
upstream=https://github.com/armbian/build.git
uboot_url=https://github.com/u-boot/u-boot.git
board=rv1126-evb-v13
args=(
    BOARD="$board" BRANCH=vendor RELEASE=trixie BUILD_MINIMAL=yes BUILD_DESKTOP=no
    KERNEL_CONFIGURE=no KERNEL_GIT=shallow PREFER_DOCKER=no SHARE_LOG=no
    "COMPRESS_OUTPUTIMAGE=sha,xz" CPUTHREADS=8
    IPVAT0901_KERNEL_REF="commit:$KERNEL_COMMIT" RKBIN_GIT_REF="commit:$RKBIN_COMMIT"
)
case "${1:-}" in
    --prepare-only|'') ;;
    *) printf 'Usage: %s [--prepare-only]\n' "$0" >&2; exit 2 ;;
esac

if [[ ! -d "$build_dir/.git" ]]; then
    git init --quiet "$build_dir"
    git -C "$build_dir" remote add origin "$upstream"
    git -C "$build_dir" fetch --depth=1 origin "$ARMBIAN_COMMIT"
    git -C "$build_dir" checkout --quiet --detach FETCH_HEAD
fi
cd -- "$build_dir"
if [[ $(git rev-parse HEAD) != "$ARMBIAN_COMMIT" ]]; then
    printf 'The build checkout must be at %s. Move build/ aside and retry.\n' "$ARMBIAN_COMMIT" >&2
    exit 1
fi
for patch in "$project_dir"/patches/*.patch; do
    if ! git apply --reverse --check "$patch" 2>/dev/null; then
        git apply --whitespace=nowarn "$patch"
    fi
done

read -r tag_sha _ < <(git ls-remote --exit-code "$uboot_url" "refs/tags/$UBOOT_TAG^{}")
if [[ "$tag_sha" != "$UBOOT_COMMIT" ]]; then
    printf 'The U-Boot tag %s resolved to an unexpected commit.\n' "$UBOOT_TAG" >&2
    exit 1
fi

if [[ "${1:-}" == --prepare-only ]]; then
    bash -n "config/boards/$board.csc"
    ./compile.sh config-dump "${args[@]}" > /dev/null
    exit 0
fi

privileged=()
if (( EUID != 0 )); then
    privileged=(sudo)
fi
"${privileged[@]}" ./compile.sh build "${args[@]}"

install -d "$dist_dir/bootloader"
shopt -s nullglob
images=(output/images/*_Rv1126-evb-v13_trixie_vendor_*_minimal.img.xz)
boot_packages=(output/debs/linux-u-boot-"$board"-vendor_*.deb)
if (( ${#images[@]} != 1 || ${#boot_packages[@]} != 1 )); then
    printf 'Expected one board image and one U-Boot package. Use a fresh build/ directory.\n' >&2
    exit 1
fi
image=$(basename -- "${images[0]}")
install -m 0644 "${images[0]}" "${images[0]}.sha" "$dist_dir"
scratch=$(mktemp -d)
trap 'rm -rf -- "$scratch"' EXIT
dpkg-deb --extract "${boot_packages[0]}" "$scratch/deb"
boot_dir=$(dirname -- "$(find "$scratch/deb/usr/lib" -name idbloader.img -print -quit)")
for file in idbloader.img u-boot.itb u-boot-rockchip.bin u-boot-spl.bin; do
    install -m 0644 "$boot_dir/$file" "$dist_dir/bootloader/"
done

cd -- "$dist_dir"
sha256sum --check "$image.sha"
xz -dc -- "$image" > "$scratch/${image%.xz}"
"${privileged[@]}" bash "$project_dir/scripts/verify-image.sh" "$scratch/${image%.xz}" "$dist_dir/bootloader" \
    2>&1 | tee image-verification.txt
{
    cat "$project_dir/sources.env"
    printf 'IPVAT0901_COMMIT=%s\n' "$(git -C "$project_dir" rev-parse HEAD)"
} > build-info.txt
sha256sum -- "$image" bootloader/* > SHA256SUMS
sha256sum --check SHA256SUMS
