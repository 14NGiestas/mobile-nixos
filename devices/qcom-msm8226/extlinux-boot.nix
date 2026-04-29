# devices/qcom-msm8226/extlinux-boot.nix
{ pkgs ? import <nixpkgs> {}, bootImg ? ./result, kernelDtbs ? null }:

let
  # Extract kernel & initrd from boot.img
  extract = pkgs.runCommand "extract-bootimg" {
    nativeBuildInputs = [ pkgs.abootimg ];
  } ''
    abootimg -x ${bootImg} bootimg.cfg zImage initrd.img
    mkdir -p $out
    cp zImage $out/zImage
    cp initrd.img $out/initrd.img
  '';
in
pkgs.runCommand "msm8226-extlinux-boot.img" {
  nativeBuildInputs = [ pkgs.genext2fs ];
} ''
  mkdir -p root/extlinux root/boot root/dtbs

  # Copy kernel artifacts
  cp ${extract}/zImage root/boot/vmlinuz
  cp ${extract}/initrd.img root/boot/initrd.img
  
  # Copy DTBs if provided (optional for mainline)
  ${pkgs.lib.optionalString (kernelDtbs != null) ''
    cp ${kernelDtbs}/*.dtb root/dtbs/ 2>/dev/null || true
  ''}

  # Create extlinux.conf per postmarketOS docs
  cat > root/extlinux/extlinux.conf << 'EOF'
timeout 1
default mainline
label mainline
  linux /boot/vmlinuz
  initrd /boot/initrd.img
  fdt /dtbs/qcom-msm8226-motorola-titan.dtb
  append earlycon console=ttyMSM0,115200 msm.allow_vram_carveout=1 cma=256m msm.vram=192m clk_ignore_unused pd_ignore_unused loglevel=8 panic=0 nomodeset
EOF

  # Generate 16MB ext2 image (lk2nd scans partitions >16MB)
  genext2fs -b 16384 -d root -v -L boot $out
''
