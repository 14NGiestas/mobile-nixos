{ config, lib, pkgs, ... }:
# https://discourse.nixos.org/t/how-to-have-a-minimal-nixos/22652/4
let
  # Firmware GPU Adreno 305 para o initramfs (stage-1)
  # Commented out to save ~3-4 MB; can be re-enabled in stage-2 later
  qcom-video-firmware = pkgs.runCommand "titan-gpu-firmware" {} ''
    mkdir -p $out/lib/firmware/qcom
    cp ${pkgs.linux-firmware}/lib/firmware/qcom/a305_pfp.fw $out/lib/firmware/qcom/ 2>/dev/null || true
    cp ${pkgs.linux-firmware}/lib/firmware/qcom/a305_pm4.fw $out/lib/firmware/qcom/ 2>/dev/null || true
  '';
in
{
  boot.kernelParams = lib.mkForce [
    "earlyprintk"
    "loglevel=8"
    "console=ttyHSL0,115200n8"
    "console=ttyGS0,115200"
    "usbcore.autosuspend=-1"
    "androidboot.battid=ignore"
  ];

  boot.initrd = {
    includeDefaultModules = false;
    availableKernelModules = lib.mkForce [
      "mmc_core" "mmc_block" "mmc_msm" "ext4" "jbd2"
    ];

    kernelModules = [];
    compressor = "gzip";  # Lower overhead than xz on small archives
    
    # Disable systemd in stage-1 (saves ~4-6 MB)
    systemd.enable = lib.mkForce false;
    network.enable = lib.mkForce false;
    postDeviceCommands = ''
      # Signal that initrd reached device initialization
      echo "=== DEBUG: Initrd post-device stage reached ===" > /dev/kmsg
      
      # Try Qualcomm timed vibrator
      if [ -e /sys/class/timed_output/vibrator/enable ]; then
        echo 400 > /sys/class/timed_output/vibrator/enable
      # Fallback to LED/vibrator via sysfs
      elif [ -e /sys/class/leds/vibrator/trigger ]; then
        echo timer > /sys/class/leds/vibrator/trigger
        sleep 0.4
        echo none > /sys/class/leds/vibrator/trigger
      fi
    '';
  };

  # 📷 Camera modules: MOVED TO STAGE-2 (not needed for boot)
  # boot.kernelModules = [ "msm_isp" "msm_camera" "media-controller" ];

  mobile = {
    device.name = "motorola-titan";
    device.identity = {
      name = "Motorola Moto G (2nd gen)";
      manufacturer = "Motorola";
    };

    device.supportLevel = "broken";

    hardware = {
      soc = "qualcomm-msm8226";
      ram = 1024 * 1;
      screen = { width = 720; height = 1280; };
    };

    boot.stage-1 = {
       # 🔥 Visibilidade em tempo real
    bootlog.kmsg = true;
    bootlog.enable = true;
    
    # 🔥 Acesso remoto via USB
    networking.enable = true;
    networking.IP = "172.16.42.2";
    networking.hostIP = "172.16.42.1";
    
    # 🔥 Shell de debug interativo
    shell.enable = true;
    shell.console = "ttyGS0";
    
    # 🔥 SSH no stage-1 (apenas para debug; desative depois)
    ssh.enable = true;
    
    # 🔥 Funções USB ativadas (RNDIS para rede, ACM para serial)
    usb.features = ["rndis" "acm" "mtp"];
      kernel = {
        #firmware = [ qcom-video-firmware ]; # Disabled to save space
        package = (pkgs.callPackage ./kernel { }).override {
          useStrictKernelConfig = false;
        };
        modular = true;
      };
      extraUtils = lib.mkForce [];
      compression = "gzip";
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

    usb = {
      mode = "android_usb";  # Switches to g_android (in-kernel enumeration)
      idVendor = "22b8";
      idProduct = "2e82";
      # Removed gadgetfs.functions (no longer needed)
    };

    system.type = "android";
    system.android.flashingMethod = "fastboot";
    
    kernel.structuredConfig = [
      (helpers: with helpers; {
        CC_OPTIMIZE_FOR_PERFORMANCE = no;
        CC_OPTIMIZE_FOR_SIZE = yes;
      })
    ];
  };

  # 🗑️ Strip NixOS closure bloat (inspired by nixfiles.md minimal profile)
  documentation.enable = lib.mkForce false;
  documentation.man.enable = lib.mkForce false;
  documentation.info.enable = lib.mkForce false;
  environment.defaultPackages = lib.mkForce [];
  xdg.icons.enable = false;
  xdg.mime.enable = false;
  xdg.sounds.enable = false;
  i18n.supportedLocales = [ "en_US.UTF-8/UTF-8" ];
}
