# RV1126 RKNN on Linux 6.1

The RV1126 galcore module uses Freescale's Vivante 6.4.3.p0.0 source at b4bed329713179146097ed8f00b8817c97fb9377. The patch adds RV1126 clock, regulator and power-domain setup, updates Linux kernel APIs, and supplies the factory VIP8000 chip entry. The driver exposes the ABI build number expected by the board's factory RKNN runtime 1.5.2. The module is built for the RV1126 vendor 6.1 kernel.

On the Linux build host, use the configured and compiled kernel tree for the target image. The directory must contain Module.symvers and include/config/kernel.release. Install the ARM hard-float cross compiler, Git and kmod.

~~~sh
bash build-rknpu-linux61.sh /path/to/compiled/linux-kernel-tree /path/to/output
cd /path/to/output
sha256sum -c galcore.ko.sha256
~~~

Use build-rknpu-ramboot.sh to extract the matching factory userspace libraries and VGG-16 fixture from the local firmware backup. Copy its initramfs.cpio.gz and the new galcore.ko to the running 6.1 system. Run the following on that system.

~~~sh
sudo bash test-rknpu-linux61.sh ./galcore.ko ./initramfs.cpio.gz
~~~

The script loads the module, checks the platform driver binding and runs the factory inference fixture. It prints RV1126_RKNN_LINUX61=PASS after receiving Top 5 values and end-to-end timing. The test unloads the module on exit. The module uses a fixed clock and keeps the NPU powered while loaded. Runtime power gating, thermal scaling and sustained load remain unverified.
