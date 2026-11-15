#!/usr/bin/env bash
set -euo pipefail

if [[ $# != 2 || $EUID != 0 ]]; then
    printf 'Usage: sudo %s GALCORE_MODULE FACTORY_TEST_INITRAMFS\n' "$0" >&2
    exit 2
fi

module=$(realpath -- "$1")
archive=$(realpath -- "$2")
release=$(uname -r)
[[ $release == 6.1.*-vendor-rockchip-rv1126 ]]
[[ $(modinfo -F vermagic "$module") == "$release "*ARMv7* ]]

if [[ -e /sys/module/galcore ]]; then
    printf 'Unload the current galcore module before testing this file.\n' >&2
    exit 1
fi

scratch=$(mktemp -d)
loaded=no
cleanup() {
    if [[ $loaded == yes ]]; then rmmod galcore; fi
    rm -rf -- "$scratch"
}
trap cleanup EXIT
( cd "$scratch"; gzip -dc "$archive" | cpio --quiet -idm --no-absolute-filenames )
cd "$scratch/rockchip_test/npu"
insmod "$module"
loaded=yes
test -c /dev/galcore
[[ $(basename "$(readlink /sys/bus/platform/devices/ffbc0000.npu/driver)") == galcore ]]
timeout -k 5 45 "$scratch/lib/ld-linux-armhf.so.3" --library-path "$scratch/usr/lib:$scratch/lib" \
    ./rknn_inference vgg_16_maxpool/vgg_16.rknn vgg_16_maxpool/goldfish_224x224.jpg 5 | tee "$scratch/inference.log"
grep -F 'Top5' "$scratch/inference.log" > /dev/null
grep -F 'With input/output:avg time:' "$scratch/inference.log" > /dev/null
printf 'RV1126_RKNN_LINUX61=PASS\n'
