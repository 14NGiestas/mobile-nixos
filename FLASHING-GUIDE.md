# Motorola Titan (MSM8226) - Flashing Guide

## Overview

The Motorola Titan uses a two-stage boot process:
1. **Bootloader (lk2nd)** - Loaded from bootloader partition, handles device initialization and DTB selection
2. **Kernel + Ramdisk** - Loaded from boot partition, runs NixOS

## Prerequisites

- Device connected via USB
- `fastboot` and `adb` tools available (from `nix-shell`)
- Device in **Fastboot Mode**
- No locked bootloader (should allow fastboot flashing)

## Entering Fastboot Mode

1. Power off the device completely
2. Hold **Volume Down + Power** simultaneously for ~10 seconds
3. You should see the Motorola bootloader menu
4. Use Volume Down to navigate to **"FASTBOOT"** option
5. Press Power to enter fastboot mode
6. Connect device via USB (if not already connected)

Verify connection:
```bash
fastboot devices
```

## Step 1: Flash lk2nd Bootloader (One-Time)

This step only needs to be done once. lk2nd will permanently replace the bootloader.

```bash
# Build lk2nd
nix-build --argstr device motorola-titan -A pkgs.lk2ndMsm8226 -o lk2nd-msm8226

# Verify the image exists
ls -lh lk2nd-msm8226/lk2nd.img

# Flash to bootloader partition
fastboot flash bootloader lk2nd-msm8226/lk2nd.img
```

### Expected output:
```
Sending 'bootloader' (299 KB)...
OKAY [  0.142s]
Writing 'bootloader'...
OKAY [  0.356s]
Finished. Total time: 0.500s
```

**After flashing lk2nd**, the device will reboot. You may see lk2nd's serial output if you have a serial adapter.

## Step 2: Build NixOS Boot Image

```bash
# Build the boot image with kernel and ramdisk
nix-build --argstr device motorola-titan -A outputs.android-bootimg -o boot.img

# Verify the image
file boot.img
strings boot.img | grep console=
```

### What's in boot.img:
- **Kernel**: Linux v6.16.12 with USB Gadget Serial support (CONFIG_USB_G_SERIAL=y)
- **Ramdisk**: NixOS minimal root filesystem with systemd
- **DTB**: msm8226-motorola-titan device tree (appended to kernel)
- **Console**: ttyGS0 @ 115200 baud (USB serial)

## Step 3: Flash Boot Image

Make sure device is still in fastboot mode:

```bash
# Flash boot image
fastboot flash boot boot.img

# Verify flash completed
fastboot getvar bootstate

# Reboot device
fastboot reboot
```

### Expected output:
```
Sending 'boot' (8192 KB)...
OKAY [  1.234s]
Writing 'boot'...
OKAY [  2.456s]
Finished. Total time: 3.690s

Rebooting...
OKAY [  0.001s]
Finished. Total time: 0.001s
```

## Step 4: Access Serial Console

After flashing, the device will boot. Within a few seconds, USB Gadget Serial should be initialized and available at `/dev/ttyACM0`.

```bash
# Wait for device to appear
sleep 5

# Monitor the boot log
screen /dev/ttyACM0 115200
# or
minicom -D /dev/ttyACM0 -b 115200
# or  
picocom -b 115200 /dev/ttyACM0
```

### Expected boot output:
```
[    0.000000] Linux version 6.16.12 (linux@titan) ...
[    0.000000] KERNEL supported cpus:
[    0.000000]   ARMv7 Processor variant: ARMv7 Processor rev 4 (v7l)
[    0.000000] Machine model: Motorola Moto G (2nd gen)
...
[    X.XXXXXX] usb 1-1: new high-speed USB device
[    X.XXXXXX] usb 1-1: New USB device found
...
```

If you see kernel output, USB Gadget Serial is working!

## Troubleshooting

### Device doesn't appear in fastboot
- Try holding buttons longer (15-20 seconds)
- Check USB cable (should be a data cable, not charge-only)
- Try different USB port
- Run `lsusb` to see if device appears at all

### Device reboots immediately after flashing
- Bootloader offsets might be wrong
- Check AGENTS.md for offset values
- Device might not have enough partition space

### No USB serial output after boot
- Kernel might not have booted
- CONFIG_USB_G_SERIAL might not be enabled
- Check USB cable and port
- Try: `dmesg` on host to see USB enumeration

### "WRITE PROTECT is on" error
- Device has fastboot write protection enabled
- Need to unlock bootloader (device-specific process)

### Stuck in bootloader loop
- lk2nd or kernel image might be corrupted
- Restore via recovery mode or use Motorola tools

## Advanced: Flashing via Recovery Mode

If fastboot is inaccessible, you can use adb in recovery:

```bash
# Wait for recovery to show up in adb
adb devices

# Push boot image
adb push boot.img /tmp/

# Flash via recovery
adb shell dd if=/tmp/boot.img of=/dev/block/by-name/boot
```

## References

- lk2nd project: https://github.com/msm8916-mainline/lk2nd
- Mobile NixOS: https://mobile-nixos.github.io/
- Motorola Titan: MSM8226, Adreno 305, 1GB RAM

## Notes

- USB Gadget Serial console is on ttyGS0 @ 115200 baud
- Device tree is provided by lk2nd bootloader
- Kernel params are passed via bootloader
- lk2nd provides proper QCDT device tree selection at runtime
