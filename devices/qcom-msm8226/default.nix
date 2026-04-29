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

  boot.initrd = {
    includeDefaultModules = false;
    availableKernelModules = lib.mkForce [
      "mmc_core" "mmc_block" "mmc_msm" "ext4" "jbd2"
    ];
    kernelModules = [];
    compressor = "gzip";
    
    postDeviceCommands = ''
      echo "=== Kernel and initrd loaded ===" > /dev/kmsg
      # Musical vibration pattern: Morse code SOS (... --- ...)
      # Short-short-short / Long-long-long / Short-short-short
      vib_path=""
      if [ -e /sys/class/timed_output/vibrator/enable ]; then
        vib_path="/sys/class/timed_output/vibrator/enable"
      elif [ -e /sys/class/leds/vibrator/trigger ]; then
        vib_path="/sys/class/leds/vibrator"
      fi
      
      if [ -n "$vib_path" ] && [ -e "$vib_path" ]; then
        # SOS pattern: . . . - - - . . .
        # Short (100ms) / Long (300ms)
        for i in 1 2 3; do echo 100 > "$vib_path"; sleep 0.15; done  # S: ...
        sleep 0.2
        for i in 1 2 3; do echo 300 > "$vib_path"; sleep 0.4; done   # O: ---
        sleep 0.2
        for i in 1 2 3; do echo 100 > "$vib_path"; sleep 0.15; done  # S: ...
      fi
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
  mobile.system.android.bootimg.flash = {
    offset_base = "0x00000000";
    offset_kernel = "0x00008000";
    offset_ramdisk = "0x01000000";
    offset_second = "0x00f00000";
    offset_tags = "0x00000100";
    pagesize = "2048";
  };
  # Let the bootloader provide its own DTB - don't override
  # The mainline kernel should work with the bootloader's DTB

  mobile.quirks.qualcomm.wcnss-wlan.enable = true;
}
