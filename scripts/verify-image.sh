#!/usr/bin/env bash
set -euo pipefail
image=$1
boot_dir=$2
scratch=$(mktemp -d)
loop=
cleanup() {
    if mountpoint -q "$scratch"; then umount "$scratch"; fi
    if [ -n "$loop" ]; then losetup -d "$loop"; fi
    rmdir "$scratch"
}
trap cleanup EXIT

printf '\nGPT\n'
sfdisk --verify "$image"
sfdisk --dump "$image"
read -r start sectors uuid < <(sfdisk --json "$image" | python3 -c '
import json, sys
table = json.load(sys.stdin)["partitiontable"]
assert table["label"] == "gpt"
assert table["sectorsize"] == 512
partition, = table["partitions"]
assert partition["start"] >= 32768
print(partition["start"], partition["size"], partition["uuid"].lower())
')

printf '\nBootROM image and U-Boot FIT\n'
for spec in idbloader.img:64 u-boot.itb:16384; do
    file=$(printf '%s' "$spec" | cut -d: -f1)
    lba=$(printf '%s' "$spec" | cut -d: -f2)
    bytes=$(stat -c %s "$boot_dir/$file")
    test "$((lba * 512 + bytes))" -le "$((start * 512))"
    cmp -n "$bytes" -i "$((lba * 512)):0" "$image" "$boot_dir/$file"
    printf '%s: exact match at LBA %s\n' "$file" "$lba"
done

loop=$(losetup --find --show --read-only --offset "$((start * 512))" --sizelimit "$((sectors * 512))" "$image")
e2fsck -fn "$loop"
fs_uuid=$(blkid -s UUID -o value "$loop")
mount -t ext4 -o ro,noload "$loop" "$scratch"

printf '\nRoot filesystem and boot files\n'
test -s "$scratch/boot/zImage"
test -s "$scratch/boot/uInitrd"
test -s "$scratch/boot/boot.scr"
test -s "$scratch/boot/dtb/rv1126-evb-v13-armbian.dtb"
test -d "$scratch/lib/modules/6.1.172-vendor-rockchip-rv1126"
dumpimage -l "$scratch/boot/boot.scr"
cat "$scratch/boot/armbianEnv.txt"
grep -Fx 'fdtfile=rv1126-evb-v13-armbian.dtb' "$scratch/boot/armbianEnv.txt"
grep -Fx "rootdev=UUID=$fs_uuid" "$scratch/boot/armbianEnv.txt"
fdtget -t s "$scratch/boot/dtb/rv1126-evb-v13-armbian.dtb" / model
fdtget -t s "$scratch/boot/dtb/rv1126-evb-v13-armbian.dtb" /ethernet@ffc40000 phy-mode
fdtget -t s "$scratch/boot/dtb/rv1126-evb-v13-armbian.dtb" /chosen stdout-path
file "$scratch/boot/zImage" "$scratch/usr/lib/systemd/systemd"
readelf -h "$scratch/usr/lib/systemd/systemd" | grep -E 'Class:|Machine:|Flags:'
readelf -h "$scratch/usr/lib/systemd/systemd" | grep -q 'hard-float ABI'
grep -E '^(BOARD|BOARDFAMILY|BRANCH|ARCH|VERSION)=' "$scratch/etc/armbian-release"
grep -E '^VERSION_CODENAME=' "$scratch/usr/lib/os-release"
printf 'Root partition PARTUUID %s\n' "$uuid"

printf '\nIMX335, CSI-2, and status LEDs\n'
dtb="$scratch/boot/dtb/rv1126-evb-v13-armbian.dtb"
config="$scratch/boot/config-6.1.172-vendor-rockchip-rv1126"
test "$(fdtget -t s "$dtb" / model)" = "Rockchip RV1126 EVB DDR3 V13"
test "$(fdtget -t s "$dtb" /ethernet@ffc40000 phy-mode)" = rmii
test "$(fdtget -t s "$dtb" /chosen stdout-path)" = serial2:1500000n8
sensor="$(fdtget -t s "$dtb" /aliases i2c1)/imx335@1a"
test "$(fdtget -t s "$dtb" "$sensor" compatible)" = sony,imx335
test "$(fdtget -t x "$dtb" "$sensor" reg)" = 1a
endpoint="$sensor/port/endpoint"
test "$(fdtget -t i "$dtb" "$endpoint" data-lanes)" = "1 2 3 4"
test "$(fdtget -t s "$dtb" /mipi-csi2-hw@ffb10000 status)" = okay
test "$(fdtget -t s "$dtb" /leds compatible)" = gpio-leds
for spec in 0:6:30:gpio1 1:3:0:gpio2; do
    IFS=: read -r index color pin controller <<< "$spec"
    led="/leds/led-$index"
    gpio=$(fdtget -t s "$dtb" /__symbols__ "$controller")
    phandle=$(fdtget -t i "$dtb" "$gpio" phandle)
    test "$(fdtget -t i "$dtb" "$led" color)" = "$color"
    test "$(fdtget -t i "$dtb" "$led" gpios)" = "$phandle $pin 1"
    test "$(fdtget -t s "$dtb" "$led" function)" = status
    test "$(fdtget -t s "$dtb" "$led" default-state)" = off
    printf 'LED %s: %s, pin %s, active-low, off\n' "$index" "$controller" "$pin"
done
for symbol in VIDEO_IMX335 VIDEO_ROCKCHIP_CIF VIDEO_ROCKCHIP_ISP VIDEO_ROCKCHIP_ISPP PHY_ROCKCHIP_MIPI_RX LEDS_GPIO; do
    grep -Fx "CONFIG_$symbol=m" "$config"
done
version=6.1.172-vendor-rockchip-rv1126
for spec in 'imx335:of:Nimx335T(null)Csony,imx335' \
            'video_rkcif:of:Nmipi-csi2-hwT(null)Crockchip,rv1126-mipi-csi2-hw' \
            'phy_rockchip_mipi_rx:of:Ncsi-dphyT(null)Crockchip,rv1126-csi-dphy' \
            'leds_gpio:of:NledsT(null)Cgpio-leds'; do
    module=$(printf '%s' "$spec" | cut -d: -f1)
    alias=$(printf '%s' "$spec" | cut -d: -f2-)
    modprobe --dirname "$scratch" --set-version "$version" --resolve-alias "$alias" | grep -Fx "$module"
done
for module in video_rkisp video_rkispp; do
    grep -Fx "$module" "$scratch/etc/modules"
    modinfo -b "$scratch" -k "$version" -F filename "$module"
done

printf '\nFresh installation\n'
test -f "$scratch/root/.not_logged_in_yet"
if grep -q '^camtest:' "$scratch/etc/passwd"; then
    printf 'Development account found in image\n' >&2
    exit 1
fi
printf 'Armbian first-login setup present; no development account\n'
