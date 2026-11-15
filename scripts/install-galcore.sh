#!/usr/bin/env bash
set -euo pipefail

if [[ $# != 2 || $EUID != 0 ]]; then
    printf 'Usage: sudo %s IMAGE GALCORE_MODULE\n' "$0" >&2
    exit 2
fi

image=$1
module=$2
read -r release _ < <(modinfo -F vermagic "$module")
[[ $release == 6.1.*-vendor-rockchip-rv1126 ]]
root=$(mktemp -d)
loop=
cleanup() {
    if mountpoint -q "$root"; then umount "$root"; fi
    if [[ -n $loop ]]; then losetup -d "$loop"; fi
    rmdir "$root"
}
trap cleanup EXIT

read -r start sectors < <(sfdisk --json "$image" | python3 -c '
import json
import sys
table = json.load(sys.stdin)["partitiontable"]
assert table["label"] == "gpt" and table["sectorsize"] == 512
partition, = table["partitions"]
print(partition["start"], partition["size"])
')
loop=$(losetup --find --show --offset "$((start * 512))" --sizelimit "$((sectors * 512))" "$image")
mount -t ext4 "$loop" "$root"
modules="$root/lib/modules/$release"
test -d "$modules"
install -Dm0644 "$module" "$modules/updates/galcore.ko"
depmod -b "$root" "$release"
