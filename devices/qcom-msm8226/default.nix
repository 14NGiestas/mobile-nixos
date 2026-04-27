{ config, lib, pkgs, ... }:
{
  mobile.device.name = "qcom-msm8226";
  mobile.device.identity.name = "Generic MSM8226 (Moto G 2014 / Titan)";
  mobile.device.identity.manufacturer = "Motorola/Qualcomm";
  mobile.device.supportLevel = "testing";

  mobile.hardware.soc = "qualcomm-msm8226";
  mobile.hardware.ram = 1024;
  mobile.hardware.screen = { width = 720; height = 1280; };

  # 🔥 Mainline console (lk2nd routes serial here)
  mobile.boot.serialConsole = "ttyMSM0,115200n8";
  mobile.boot.defaultConsole = "ttyMSM0,115200n8";

  boot.kernelParams = lib.mkForce [
    "console=ttyMSM0,115200n8"
    "earlycon=msm_serial_dm,0xf991e000"
    "loglevel=8"
    "initrd=0x84000000,16M"
    "usbcore.autosuspend=-1"
  ];

  mobile.boot.stage-1 = {
    # 🔥 Mainline kernel + modules
    kernel = {
      package = pkgs.callPackage ./kernel { };
      modular = true;  # Mainline expects modules
      useStrictKernelConfig = false;
    };

    # 🔥 USB networking via configfs (no g_android)
    networking.enable = true;
    networking.IP = "172.16.42.2";
    networking.hostIP = "172.16.42.1";

    # 🔥 Debug shell & SSH
    shell.enable = true;
    shell.console = "ttyMSM0";
    ssh.enable = true;

    # 🔥 configfs functions (ACM serial + RNDIS network)
    usb.features = [ "acm" "rndis" ];

    compression = "gzip";
    extraUtils = lib.mkForce [];
  };

  # 🔥 Android bootimg (lk2nd expects standard header)
  mobile.system.type = "android";
  mobile.system.android.device_name = "msm8226";
  mobile.system.android.bootimg.flash = {
    offset_base = "0x80000000";
    offset_kernel = "00008000";
    offset_ramdisk = "01000000";
    offset_second = "00f00000";  # 🔥 ADDED: Required by the bootimg builder
    offset_tags = "00000100";
    pagesize = "2048";
  };

  # 🔥 Mainline quirks (postmarketOS verified)
  mobile.quirks.qualcomm.wcnss-wlan.enable = true;
  mobile.quirks.fb-refresher.enable = true;
}
