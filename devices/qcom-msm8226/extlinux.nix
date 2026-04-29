{ config, pkgs, lib, ... }:
let
  inherit (config.mobile.outputs.android) android-bootimg;
  inherit (config.mobile.outputs.stage-0.mobile.boot.stage-1) kernel;
in
{
  options.mobile.outputs.extlinux-bootimg = lib.mkOption {
    type = pkgs.lib.types.package;
    description = "ext2 image with kernel, initrd and extlinux.conf for lk2nd";
    visible = false;
  };

  config.mobile.outputs.extlinux-bootimg = pkgs.callPackage ./extlinux-boot.nix {
    bootImg = android-bootimg;
    kernelDtbs = "${kernel.package}/dtbs";
  };
}
