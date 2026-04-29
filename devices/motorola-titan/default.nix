{ config, lib, pkgs, ... }:
let
  # Firmware GPU Adreno 305 (optional, can be re-enabled in stage-2)
  qcom-video-firmware = pkgs.runCommand "titan-gpu-firmware" {} ''
    mkdir -p $out/lib/firmware/qcom
    cp ${pkgs.linux-firmware}/lib/firmware/qcom/a305_pfp.fw $out/lib/firmware/qcom/ 2>/dev/null || true
    cp ${pkgs.linux-firmware}/lib/firmware/qcom/a305_pm4.fw $out/lib/firmware/qcom/ 2>/dev/null || true
  '';
in
{
  # 🔥 Android/Qualcomm boot params (from deviceinfo + pmOS wiki)
  # These are overridden in local.nix to include root filesystem parameters
  boot.kernelParams = lib.mkForce [
    "androidboot.bootdevice=msm_sdcc.1"
    "androidboot.hardware=qcom"
    "vmalloc=400M"
    "utags.blkdev=/dev/block/platform/msm_sdcc.1/by-name/utags"
  ];

  # 🔥 Minimal initrd for 10MB boot partition
  boot.initrd = {
    includeDefaultModules = false;
    availableKernelModules = lib.mkForce [
      "mmc_core" "mmc_block" "mmc_msm" "ext4" "jbd2"
    ];
    kernelModules = [];
    compressor = "gzip";
    
    systemd.enable = lib.mkForce false;
    network.enable = lib.mkForce false;
    
    postDeviceCommands = ''
      echo "=== DEBUG: Initrd post-device stage reached ===" > /dev/kmsg
      if [ -e /sys/class/timed_output/vibrator/enable ]; then
        echo 400 > /sys/class/timed_output/vibrator/enable
      elif [ -e /sys/class/leds/vibrator/trigger ]; then
        echo timer > /sys/class/leds/vibrator/trigger
        sleep 0.4
        echo none > /sys/class/leds/vibrator/trigger
      fi
    '';
  };

  mobile = {
    device.name = "motorola-titan";
    device.identity = {
      name = "Motorola Moto G (2nd gen)";
      manufacturer = "Motorola";
    };
    device.supportLevel = "broken";

    hardware = {
      soc = "qualcomm-msm8226";
      ram = 1024;
      screen = { width = 720; height = 1280; };
    };

    boot.stage-1 = {
      # Keep only debug essentials
      networking.enable = true;
      networking.IP = "172.16.42.2";
      networking.hostIP = "172.16.42.1";
      ssh.enable = true;
      usb.features = [ "rndis" "acm" ];
      gui.enable = false;
      bootlog.enable = true;
      bootlog.kmsg = true;
      
      kernel = {
        package = pkgs.callPackage ./kernel { useStrictKernelConfig = false; };
        modular = false;
      };
      
      compression = "gzip";
      # extraUtils is configured in local.nix to ensure proper stage-1 tools
    };

    device.firmware = pkgs.callPackage ./firmware {};
    device.enableFirmware = false;

    system.android.device_name = "titan";
    system.android.bootimg.flash = {
      offset_base = "0x00000000";
      offset_kernel = "00008000";
      offset_ramdisk = "01000000";
      offset_second = "00f00000";
      offset_tags = "00000100";
      pagesize = "2048";
    };
    system.android.bootimg.dt = lib.mkForce null;  # lk2nd provides DTB from bootloader
    
    # Use Titan DTB from lk2nd build (required for lk2nd to accept kernel)
    system.android.appendDTB = lib.mkDefault [
      "${pkgs.lk2ndMsm8226}/dtb/msm8226-motorola-titan.dtb"
    ];

    usb = {
      mode = "android_usb";  # g_android (downstream)
      idVendor = "22b8";
      idProduct = "2e82";
    };

    system.type = "android";
    system.android.flashingMethod = "fastboot";
    
    kernel.structuredConfig = [
      (helpers: with helpers; {
        CC_OPTIMIZE_FOR_PERFORMANCE = no;
        CC_OPTIMIZE_FOR_SIZE = yes;
      })
    ];
    
    # ✅ Official Titan quirks (postmarketOS wiki)
    quirks.qualcomm.wcnss-wlan.enable = true;   # WiFi init via /dev/wcnss_wlan
    quirks.fb-refresher.enable = true;          # Workaround for Wayland black screen
  };

  # 🗑️ Strip NixOS bloat for minimal stage-1
  documentation.enable = lib.mkForce false;
  documentation.man.enable = lib.mkForce false;
  documentation.info.enable = lib.mkForce false;
  environment.defaultPackages = lib.mkForce [];
  xdg.icons.enable = false;
  xdg.mime.enable = false;
  xdg.sounds.enable = false;
  i18n.supportedLocales = [ "en_US.UTF-8/UTF-8" ];
}
