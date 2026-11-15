#!/usr/bin/env bash
set -euo pipefail

if [[ $# != 2 ]]; then
    printf 'Usage: %s PREPARED_KERNEL_TREE OUTPUT_DIRECTORY\n' "$0" >&2
    exit 2
fi

kernel=$(realpath -- "$1")
output=$(realpath -m -- "$2")
script_dir=$(cd -- "$(dirname -- "$0")" && pwd)
cross_compile=${CROSS_COMPILE:-arm-linux-gnueabihf-}
source_url=https://github.com/Freescale/kernel-module-imx-gpu-viv.git
source_commit=b4bed329713179146097ed8f00b8817c97fb9377

release=$(<"$kernel/include/config/kernel.release")
if [[ $release != 6.1.*-vendor-rockchip-rv1126 || ! -s "$kernel/Module.symvers" ]]; then
    printf 'Use the compiled RV1126 vendor 6.1 kernel tree for the target image.\n' >&2
    exit 1
fi

scratch=$(mktemp -d)
trap 'rm -rf -- "$scratch"' EXIT
git -C "$scratch" init --quiet
git -C "$scratch" fetch --depth=1 "$source_url" "$source_commit"
git -C "$scratch" checkout --quiet --detach FETCH_HEAD
git -C "$scratch" apply --whitespace=error "$script_dir/galcore-linux61.patch"

driver="$scratch/kernel-module-imx-gpu-viv-src"
make -C "$kernel" M="$driver" AQROOT="$driver" ARCH=arm CROSS_COMPILE="$cross_compile" \
    SOC_PLATFORM=rockchip-rv1126 KCFLAGS=-DLINUX_CMA_FSL=0 -j "${JOBS:-8}" modules
"${cross_compile}strip" --strip-debug "$driver/galcore.ko"
vermagic=$(modinfo -F vermagic "$driver/galcore.ko")
[[ $vermagic == "$release "*ARMv7* ]]
install -d "$output"
install -m 0644 "$driver/galcore.ko" "$output/"
( cd "$output"; sha256sum galcore.ko > galcore.ko.sha256 )
