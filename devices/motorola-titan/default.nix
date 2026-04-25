{ config, lib, pkgs, ... }:

let
  # Firmware GPU Adreno 305 para o initramfs (stage-1)
  qcom-video-firmware = pkgs.runCommand "titan-gpu-firmware" {} ''
    mkdir -p $out/lib/firmware/qcom
    # Usa caminhos explícitos + || true para não travar se o arquivo não existir no linux-firmware atual
    cp ${pkgs.linux-firmware}/lib/firmware/qcom/a305_pfp.fw $out/lib/firmware/qcom/ 2>/dev/null || true
    cp ${pkgs.linux-firmware}/lib/firmware/qcom/a305_pm4.fw $out/lib/firmware/qcom/ 2>/dev/null || true
  '';
in
{
  mobile = {
    device.name = "motorola-titan";
    device.identity = {
      name = "Motorola Moto G (2nd gen)";
      manufacturer = "Motorola";
    };
    # The boot image is currently too big to fit.
    device.supportLevel = "broken";

    hardware = {
      soc = "qualcomm-msm8226";
      ram = 1024 * 1;
      screen = {
        width = 720; height = 1280;
      };
    };

    boot.stage-1.firmware = [
      qcom-video-firmware
    ];

    boot.stage-1.kernel = {
      package = pkgs.callPackage ./kernel { };
    };

    # in your configuration.nix hardware.firmware, in addition to this
    # package you will probably need pkgs.linux-firmware, pkgs.wireless-regdb
    device.firmware = pkgs.callPackage ./firmware {};
    # Firmware is not enabled by default since it requires manually providing unredistributable files.
    device.enableFirmware = false;

    system.android.device_name = "titan";
    system.android = {
    # FIXME: These values may need to be adjusted for titan
      bootimg.flash = {
        offset_base = "0x00000000";
        offset_kernel = "0x00008000";
        offset_ramdisk = "0x01000000";
        offset_second = "0x00f00000";
        offset_tags = "0x00000100";
        pagesize = "2048";
      };
    };

    # The boot partition on this phone is 10MB, so use `xz` compression
    # as smaller than gzip
    boot.stage-1.compression = lib.mkDefault "xz";

    usb = {
      mode = "gadgetfs";
      idVendor = "22b8";  # Motorola
        idProduct = "2e82"; # Moto G (tethering)
        gadgetfs.functions = {
          rndis = "rndis.usb0";
          adb = "ffs.adb";
        };
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
}

