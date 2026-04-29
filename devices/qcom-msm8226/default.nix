{ config, lib, pkgs, ... }:
{
  mobile.device.name = "qcom-msm8226";
  mobile.device.identity.name = "Generic MSM8226 (Moto G 2014 / Titan)";
  mobile.device.identity.manufacturer = "Motorola/Qualcomm";
  mobile.device.supportLevel = "testing";

  mobile.hardware.soc = "qualcomm-msm8226";
  mobile.hardware.ram = 1024;
  mobile.hardware.screen = { width = 720; height = 1280; };

  mobile.quirks.fb-refresher.enable = false;

  boot.kernelParams = lib.mkForce [
    "console=ttyGS0,115200"
    "loglevel=8"
  ];

  mobile.boot.stage-1 = {
    kernel = {
      package = pkgs.callPackage ./kernel { };
      modular = false;
      useStrictKernelConfig = false;
    };

    compression = "gzip";
    networking.enable = false;
    shell.enable = true;
    ssh.enable = false;
    usb.features = [ "acm" "rndis" ];
    extraUtils = lib.mkForce [];
  };

  mobile.system.type = "android";
  mobile.system.android.device_name = "titan";
  mobile.system.android.bootimg.flash = {
    offset_base = "0x00000000";
    offset_kernel = "0x00008000";
    offset_ramdisk = "0x01000000";
    offset_second = "0x00f00000";
    offset_tags = "0x00000100";
    pagesize = "2048";
  };
  mobile.system.android.bootimg.dt = lib.mkForce null;
  
  # Use Titan DTB from lk2nd build (contains QCDT device tree selection info)
  mobile.system.android.appendDTB = lib.mkDefault [
    "${pkgs.lk2ndMsm8226}/dtb/msm8226-motorola-titan.dtb"
  ];

  mobile.quirks.qualcomm.wcnss-wlan.enable = true;
}
