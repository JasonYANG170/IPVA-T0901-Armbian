# RV1126 RKNPU v1 内存启动测试

此启动包使用 IPVAT0901 的原厂 4.19.111 内核、设备树、galcore 和 RKNN 运行库。启动后加载 /dev/galcore，执行原厂 VGG-16 示例，输出 Top 5 特征和耗时，再重启回常规的 Armbian。6.1 镜像中的 RKNN 原生推理仍需匹配的 RV1126 galcore 驱动。

在 WSL 或 Ubuntu 安装 python3、kmod、util-linux、fdisk、cpio、device-tree-compiler 和 u-boot-tools。运行构建脚本并指定原厂整盘备份、提取的原厂内核 DTB 和输出目录。

~~~sh
sudo bash /path/to/build-rknpu-ramboot.sh \
  /path/to/RV1126_emmc_full.img /path/to/rk-kernel.dtb /path/to/npu-ramboot
cd /path/to/npu-ramboot
sha256sum -c SHA256SUMS
~~~

把生成的文件复制到板上 Armbian 的 /boot/rv1126-npu-validation/。通过 UART2 串口使用 1500000 8N1，在 U-Boot 的倒计时期间按键。对本板的 eMMC 安装执行以下命令。

~~~text
load mmc 0:1 0x01000000 /boot/rv1126-npu-validation/rknpu-boot.scr
source 0x01000000
~~~

串口出现 RV1126_NPU_RESULT=PASS 代表程序成功完成运行、读取了模型输出并记录了端到端耗时。默认 Armbian 的引导文件和 U-Boot 持久环境由原来的启动流程管理。原厂备份、派生二进制和模型从本地读取。
