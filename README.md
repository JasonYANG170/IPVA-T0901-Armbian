[简体中文](README_zh.md) | [English](README.md)

# IPVA-T0901 Armbian

Armbian Minimal for the IPVA-T0901 camera board.

## Device Info

- **SoC**: Rockchip RV1126, quad-core Cortex-A7, 32-bit armhf
- **OS**: Debian Trixie with vendor Linux 6.1.172
- **Board**: RV1126 EVB DDR3 V13, eMMC boot, RMII Ethernet, Sony IMX335
- **Bootloader**: U-Boot v2026.10
- **DTB**: `rv1126-evb-v13-armbian.dtb`
- **NPU**: Ported `galcore` driver. Use the RV1126 RKNN 1.x runtime for inference.
- **UART2**: 1500000 baud, 8N1

## Build

### GitHub Actions

Push to `main` or run **Build Armbian** from the Actions tab. Successful builds publish the compressed disk image, U-Boot and SPL, `galcore.ko`, and SHA-256 checksums on [Releases](https://github.com/JasonYANG170/IPVA-T0901_Armbian/releases).

### Local Build

Use Ubuntu 24.04 x86-64 or WSL2 with loop devices and sudo. Keep the checkout on a Linux filesystem.

```bash
sudo apt-get update
sudo apt-get install -y git device-tree-compiler gcc-arm-linux-gnueabihf kmod u-boot-tools xz-utils
bash scripts/build.sh
```

Find the artifacts in `dist/`. Run `sha256sum -c SHA256SUMS` from that directory to verify them.
