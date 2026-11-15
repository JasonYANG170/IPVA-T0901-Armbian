# Load from the same eMMC partition as the standard RV1126 image.
setenv npu_path /boot/rv1126-npu-validation
load mmc 0:1 ${kernel_addr_r} ${npu_path}/zImage || exit
load mmc 0:1 ${ramdisk_addr_r} ${npu_path}/initramfs.cpio.gz || exit
setenv npu_ramdisk_size ${filesize}
load mmc 0:1 ${fdt_addr_r} ${npu_path}/stock.dtb || exit
setenv bootargs earlycon=uart8250,mmio32,0xff570000 console=ttyFIQ0 rdinit=/init loglevel=4
bootz ${kernel_addr_r} ${ramdisk_addr_r}:${npu_ramdisk_size} ${fdt_addr_r}
