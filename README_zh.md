# IPVAT0901-Armbian

[English](README.md)

这个项目为 IPVAT0901 构建 Debian Trixie Minimal（32 位 armhf）。板级配置沿用 Rockchip RV1126 EVB DDR3 V13，使用 vendor Linux 6.1。镜像集成 eMMC 启动、RMII 有线网、Sony IMX335 摄像头和两路状态灯。UART2 串口参数为 1500000 8N1。

在 GitHub 的 **Actions** 里手动运行 **Build Armbian**，推送到 main 也会自动构建。PR 会检查补丁应用和板型配置。构建完成后下载 **IPVAT0901-Armbian-trixie-armhf**，其中包含压缩整盘镜像、U-Boot、SPL、SHA-256 和镜像验证记录。

本地可在 Ubuntu 24.04 x86-64 或 WSL2 中构建。将源码放在 Linux 文件系统，准备好 sudo 和内核构建所需的磁盘空间。GitHub Actions 使用同一个脚本。

~~~sh
sudo apt-get update
sudo apt-get install -y git device-tree-compiler kmod u-boot-tools
bash scripts/build.sh --prepare-only
bash scripts/build.sh
~~~

产物位于 dist/。在该目录执行 sha256sum --check SHA256SUMS 校验。解压 .img.xz 后，将 .img 从目标 eMMC 起始位置写入。整盘镜像已包含引导组件，写入会覆盖原分区表和系统，请先确认目标磁盘和备份。

开发版已实测 eMMC 启动、网口、IMX335 采集和两路状态灯。打包后的整盘镜像仍待实机复测。

## RKNN 硬件推理

当前 RV1126 vendor 6.1 镜像无法执行 RKNN 硬件推理。实机的 NPU 节点已启用，但没有绑定驱动，也没有 /dev/galcore。原厂 galcore 模块对应 Linux 4.19.111。需要与内核和运行库匹配的 RV1126 RKNPU v1 驱动。[Rockchip RKNPU v1 SDK](https://github.com/airockchip/rknpu)

具备兼容驱动后，先在实机确认 /dev/galcore 存在，再运行官方 MobileNet 示例的 run_rv1109_rv1126.sh，并记录实际推理输出。[Rockchip MobileNet demo](https://github.com/airockchip/rknpu/tree/64c0ec575f18d43e41a66e10b68aba4266f25386/rknn/rknn_api/examples/rknn_mobilenet_demo)

依赖源码版本见 [sources.env](sources.env)。项目的构建结构参考了 [TorderTable-Armbian](https://github.com/JasonYANG170/TorderTable-Armbian)。
