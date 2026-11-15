#!/usr/bin/env bash
set -euo pipefail

if [[ $# != 3 ]]; then
    printf 'Usage: sudo %s ORIGINAL_EMMC_IMAGE FACTORY_KERNEL_DTB OUTPUT_DIR\n' "$0" >&2
    exit 2
fi

image=$(realpath -- "$1")
dtb=$(realpath -- "$2")
destination=$(realpath -m -- "$3")
script_dir=$(cd -- "$(dirname -- "$0")" && pwd)

test "$(fdtget -t s "$dtb" /npu@ffbc0000 compatible)" = rockchip,npu
test "$(fdtget -t s "$dtb" /npu@ffbc0000 status)" = okay
partitions=$(sfdisk --json "$image" | python3 -c '
import json
import sys

table = json.load(sys.stdin)["partitiontable"]
if table["label"] != "gpt" or table["sectorsize"] != 512:
    sys.exit("Expected the factory GPT image with 512-byte sectors")
for name in ("boot_a", "system_a"):
    partition, = (item for item in table["partitions"] if item.get("name") == name)
    print(partition["start"], partition["size"])
')
read -r boot_start boot_sectors <<< "$(head -n 1 <<< "$partitions")"
read -r system_start system_sectors <<< "$(tail -n 1 <<< "$partitions")"

work=$(mktemp -d)
loop=
cleanup() {
    if mountpoint -q "$work/factory"; then umount "$work/factory" || return; fi
    if [[ -n "$loop" ]]; then losetup -d "$loop"; fi
    rm -rf -- "$work"
}
trap cleanup EXIT
mkdir -p "$work/factory" "$work/output" "$work/root"/{bin,dev,proc,sys,tmp,run,lib/modules,usr/lib,rockchip_test/npu}
factory="$work/factory"
root="$work/root"
output="$work/output"
loop=$(losetup --find --show --read-only --offset "$((system_start * 512))" \
    --sizelimit "$((system_sectors * 512))" "$image")
mount -t squashfs -o ro "$loop" "$factory"
modinfo -F vermagic "$factory/lib/modules/galcore.ko" | grep '^4\.19\.111 .*ARMv7'

python3 - "$image" "$boot_start" "$boot_sectors" "$output/zImage" <<'PY'
import struct
import sys
from pathlib import Path

image, start, sectors, output = sys.argv[1:]
with open(image, "rb") as source:
    source.seek(int(start) * 512)
    header = source.read(48)
    if header[:8] != b"ANDROID!":
        sys.exit("Factory boot_a does not contain an Android boot image")
    kernel_size, _, _, _, _, _, _, page_size = struct.unpack_from("<8I", header, 8)
    if page_size not in (2048, 4096, 8192, 16384) or page_size + kernel_size > int(sectors) * 512:
        sys.exit("Invalid kernel size in factory boot image")
    source.seek(int(start) * 512 + page_size)
    payload = source.read(kernel_size)
if len(payload) != kernel_size or payload[0x24:0x28] != b"\x18\x28\x6f\x01":
    sys.exit("Factory kernel is not an ARM zImage")
Path(output).write_bytes(payload)
PY

install -m 0755 "$factory/bin/busybox" "$root/bin/busybox"
ln -s busybox "$root/bin/sh"
cp -a "$factory"/lib/*.so* "$root/lib/"
shopt -s nullglob
libraries=("$factory"/usr/lib/{libstdc++,libgcc_s,libGAL,libArchModelSw,libVSC,libNN,libOpenVX,libOpenCL,libCLC,libOvx,librknn,libjpeg,libdrm}*)
cp -a -- "${libraries[@]}" "$root/usr/lib/"
cp -a "$factory/lib/modules/galcore.ko" "$root/lib/modules/"
cp -a "$factory/rockchip_test/npu/rknn_inference" \
    "$factory/rockchip_test/npu/vgg_16_maxpool" "$root/rockchip_test/npu/"
install -m 0644 "$dtb" "$output/stock.dtb"
cat > "$root/init" <<'INIT'
#!/bin/sh
export PATH=/bin:/sbin:/usr/bin:/usr/sbin
export LD_LIBRARY_PATH=/usr/lib:/lib
busybox mount -t devtmpfs devtmpfs /dev
busybox mount -t proc proc /proc
busybox mount -t sysfs sysfs /sys
exec </dev/console >/dev/console 2>&1
echo RV1126_NPU_BOOT
busybox uname -r
if busybox insmod /lib/modules/galcore.ko && [ -c /dev/galcore ]; then
    busybox ls -l /dev/galcore
    cd /rockchip_test/npu || exit 1
    ./rknn_inference vgg_16_maxpool/vgg_16.rknn vgg_16_maxpool/goldfish_224x224.jpg 5 > /tmp/inference.log 2>&1
    result=$?
    busybox cat /tmp/inference.log
    echo "RV1126_NPU_DEMO_EXIT=$result"
    if [ "$result" -eq 0 ] &&
        busybox grep -q 'Top5' /tmp/inference.log &&
        busybox grep -q '^With input/output:avg time:' /tmp/inference.log; then
        echo RV1126_NPU_RESULT=PASS
    else
        echo RV1126_NPU_RESULT=FAIL
    fi
else
    echo RV1126_NPU_NO_GALCORE
    echo RV1126_NPU_RESULT=FAIL
fi
busybox dmesg | busybox grep -iE 'galcore|ffbc0000|GPU.*hang'
echo RV1126_NPU_TEST_END
busybox sleep 6
busybox reboot -f
exec /bin/sh
INIT
chmod 0755 "$root/init"
( cd "$root"; find . -print0 | LC_ALL=C sort -z | cpio --quiet -o -0 -H newc | gzip -1 ) > "$output/initramfs.cpio.gz"
mkimage -A arm -T script -C none -n 'RV1126 RKNPU v1 test' \
    -d "$script_dir/rv1126-rknpu-boot.cmd" "$output/rknpu-boot.scr"
( cd "$output"; sha256sum zImage stock.dtb initramfs.cpio.gz rknpu-boot.scr > SHA256SUMS )
install -d "$destination"
install -m 0644 "$output"/{zImage,stock.dtb,initramfs.cpio.gz,rknpu-boot.scr,SHA256SUMS} "$destination"
