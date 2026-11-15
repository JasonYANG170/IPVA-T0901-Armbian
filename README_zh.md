[简体中文](README_zh.md) | [English](README.md)

# IPVA-T0901 Armbian

适用于 IPVA-T0901 摄像头主板的 Armbian Minimal 镜像。

## 设备信息

- **SoC**：Rockchip RV1126，四核 Cortex-A7，32 位 armhf
- **系统**：Debian Trixie，vendor Linux 6.1.172
- **板型**：RV1126 EVB DDR3 V13，支持 eMMC 启动、RMII 网口和 Sony IMX335
- **设备树**：`rv1126-evb-v13-armbian.dtb`
- **NPU**：移植版 `galcore` 驱动，推理使用 RV1126 的 RKNN 1.x 运行库
- **UART2**：1500000 波特率，8N1

## 构建

### GitHub Actions

推送到 `main` 或在 Actions 页面手动运行 **Build Armbian**。构建通过后，压缩整盘镜像、U-Boot 和 SPL、`galcore.ko` 以及 SHA-256 校验文件发布到 [Releases](https://github.com/JasonYANG170/IPVA-T0901_Armbian/releases)。

### 本地构建

使用 Ubuntu 24.04 x86-64 或具备 loop 设备和 sudo 的 WSL2。把源码放在 Linux 文件系统中。

```bash
sudo apt-get update
sudo apt-get install -y git device-tree-compiler gcc-arm-linux-gnueabihf kmod u-boot-tools xz-utils
bash scripts/build.sh
```

产物位于 `dist/`，进入该目录后执行 `sha256sum -c SHA256SUMS` 校验。
