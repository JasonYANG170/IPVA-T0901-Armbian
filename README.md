# IPVAT0901-Armbian

[简体中文](README_zh.md)

Armbian Debian Trixie Minimal (32-bit armhf) for the IPVAT0901 project. The board configuration uses the Rockchip RV1126 EVB DDR3 V13 profile and vendor Linux 6.1. It includes eMMC boot, RMII Ethernet, the Sony IMX335 camera, and two status LEDs. The UART2 console uses 1500000 baud, 8N1.

In GitHub Actions, run **Build Armbian**. Pushes to main also build the image. Pull requests check that the patches apply and Armbian recognizes the board. Download **IPVAT0901-Armbian-trixie-armhf** from the completed run. It includes the compressed disk image, U-Boot and SPL files, SHA-256 sums, and verification output.

To build on Ubuntu 24.04 x86-64, clone this project onto a Linux filesystem. The build needs sudo and enough disk space for the kernel and root filesystem. The same script runs on a GitHub-hosted runner.

~~~sh
sudo apt-get update
sudo apt-get install -y git device-tree-compiler kmod u-boot-tools
bash scripts/build.sh --prepare-only
bash scripts/build.sh
~~~

Output goes to dist/. Verify it with sha256sum --check SHA256SUMS from that directory. Decompress the .img.xz and write the .img to the start of the target eMMC. This replaces its partition table and operating system. Keep a verified backup before writing. The disk image already includes the bootloader.

The development image was tested for eMMC boot, Ethernet, IMX335 capture, and both status LEDs. Booting the packaged image on hardware remains to be verified.

## RKNN acceleration

The local RAM boot package runs the factory RV1126 RKNPU v1 stack and the VGG-16 test on Linux 4.19.111. It runs from an initramfs and returns to the regular Armbian boot after the test. [Build and boot instructions](scripts/rv1126-rknpu-ramboot.md)

The native Linux 6.1 galcore port runs the factory RKNN 1.5.2 VGG-16 test on this board. Build the module against the kernel tree used for the target image. [Linux 6.1 module and test instructions](scripts/rv1126-rknpu-linux61.md)

The Armbian framework, vendor kernel, U-Boot and rkbin revisions are listed in [sources.env](sources.env). The build structure follows [TorderTable-Armbian](https://github.com/JasonYANG170/TorderTable-Armbian).
