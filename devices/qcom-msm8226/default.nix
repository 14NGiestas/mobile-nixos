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
    "lk2nd.pass-ramoops"
  ];

  boot.initrd = {
    includeDefaultModules = false;
    availableKernelModules = lib.mkForce [
      "mmc_core" "mmc_block" "mmc_msm" "ext4" "jbd2"
    ];
    kernelModules = [];
    compressor = "gzip";
    
    postDeviceCommands = ''
      vib() {
        local duration=$1
        if [ -e /sys/class/timed_output/vibrator/enable ]; then
          echo $duration > /sys/class/timed_output/vibrator/enable
        elif [ -e /sys/class/leds/vibrator/trigger ]; then
          echo $duration > /sys/class/leds/vibrator
        fi
      }
      
      # Stage 1: initrd reached
      vib 100
      sleep 0.5
      
      # Try to set up basic filesystems
      [ -d /sys ] || mount -t sysfs sysfs /sys 2>/dev/null
      [ -d /proc ] || mount -t proc proc /proc 2>/dev/null
      [ -d /dev ] || mount -t devtmpfs devtmpfs /dev 2>/dev/null
      
      # Stage 2: filesystems mounted
      vib 100
      sleep 0.5
      
      # Try to load USB modules
      modprobe g_serial 2>/dev/null || true
      
      # Stage 3: USB attempted
      vib 100
    '';
  };

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
  mobile.system.android.bootimg = {
    second = lib.mkDefault "${pkgs.lk2ndMsm8226}/lk2nd.img";
    flash = {
      offset_base = "0x00000000";
      offset_kernel = "0x00008000";
      offset_ramdisk = "0x01000000";
      offset_second = "0x00f00000";
      offset_tags = "0x00000100";
      pagesize = "2048";
    };
    dt = lib.mkForce null;  # Use bootloader DTB, not kernel-generated
  };
  # Let the bootloader provide its own DTB - don't override
  # The mainline kernel should work with the bootloader's DTB

  mobile.quirks.qualcomm.wcnss-wlan.enable = true;
  mobile.system.android.appendDTB = [ "${pkgs.lk2ndMsm8226}/dtb/msm8226-motorola-titan.dtb" ];
}
