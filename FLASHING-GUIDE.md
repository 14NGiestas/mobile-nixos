# Motorola Titan (MSM8226) - Flashing Guide

## Overview

The Motorola Titan uses a two-stage boot process:
1. **Primary bootloader** - Device's original bootloader (stays unchanged)
2. **Second-stage bootloader (lk2nd)** - Embedded in boot partition, handles device initialization and DTB selection
3. **Kernel + Ramdisk** - Also in boot partition, runs NixOS

The boot image (boot.img) contains all three stages combined.

## Prerequisites

- Device connected via USB
- `fastboot` tool available (from `nix-shell`)
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

## Step 1: Build NixOS Boot Image (with embedded lk2nd)

This single build step creates a complete boot image with:
- lk2nd second-stage bootloader
- Linux kernel v6.16.12
- NixOS ramdisk
- Device tree

```bash
# Build the complete boot image
nix-build --argstr device motorola-titan -A outputs.android-bootimg -o boot.img

# Verify the image
file boot.img
ls -lh boot.img

# Verify console configuration
strings boot.img | grep console=
```

### What's in boot.img:
- **lk2nd bootloader** - Initializes hardware, detects device, loads correct DTB
- **Kernel**: Linux v6.16.12 with USB Gadget Serial support (CONFIG_USB_G_SERIAL=y)  
- **Ramdisk**: NixOS minimal root filesystem with systemd
- **DTB**: msm8226-motorola-titan device tree (appended to kernel)
- **Console**: ttyGS0 @ 115200 baud (USB serial)

## Step 2: Flash Boot Image

Make sure device is still in fastboot mode:

```bash
# Flash boot image (contains lk2nd + kernel + ramdisk)
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

## Step 3: Access Serial Console

After flashing, the device will boot. Within a few seconds, USB Gadget Serial should be initialized and available at `/dev/ttyACM0`.

```bash
# Wait for device to appear and boot
sleep 10

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
[ systemd boot messages ]
```

If you see kernel output, USB Gadget Serial and lk2nd are working!

## Boot Process (What Happens)

1. **Device powers on**
   - Original Motorola bootloader loads
   
2. **lk2nd second-stage bootloader runs**
   - Initializes MSM8226 SoC (clocks, regulators, USB)
   - Reads QCDT device tree container
   - Selects correct DTB for device (msm8226-motorola-titan)
   - Initializes USB Gadget Serial for ttyGS0
   - Loads and boots kernel

3. **Linux kernel boots**
   - Initializes hardware with device tree
   - Mounts NixOS ramdisk as root
   - Hands off to systemd

4. **NixOS stage-1 initializes**
   - Enables networking (if configured)
   - Mounts root filesystem
   - Boots full NixOS system

## Troubleshooting

### Device doesn't appear in fastboot
- Try holding buttons longer (15-20 seconds)
- Check USB cable (should be a data cable, not charge-only)
- Try different USB port
- Run `lsusb` to see if device appears at all
- Try connecting to computer directly, not through hub

### Device reboots immediately after flashing
- Boot image might be corrupted during flashing
- Try flashing again
- Check USB connection stability
- Device partition might be too small

### No USB serial output after boot
- Device might not have booted yet - wait 10-15 seconds
- Kernel might not have booted - check for lk2nd messages first
- CONFIG_USB_G_SERIAL might not be enabled in kernel
- Check USB cable and port
- Try: `lsusb` on host to see if device enumerated
- Check host dmesg: `dmesg | tail -20`

### "WRITE PROTECT is on" error
- Device has fastboot write protection enabled
- Need to unlock bootloader (device-specific process)
- Contact manufacturer for unlock instructions

### Stuck in bootloader loop
- Boot image might be corrupted
- Device might not have enough space in boot partition
- Try rebuilding boot image

### Device gets hot during boot
- Might be a bootloop consuming CPU
- Check USB serial output for errors
- Power cycle and check for serial messages

## Advanced Troubleshooting

### Check device info before flashing
```bash
fastboot getvar product      # Should show "titan" or similar
fastboot getvar bootloader   # Shows bootloader version
fastboot getvar serialno     # Shows device serial
```

### Extract and inspect boot.img
```bash
# Install abootimg if needed
sudo apt-get install abootimg

# Extract components
abootimg -x boot.img boot.cfg kernel initrd

# Check kernel magic
file kernel

# Check ramdisk magic  
file initrd

# Verify console parameter
strings kernel | grep console=
```

### Serial console from device
If you have a USB-to-serial adapter connected to UART pins, you might see additional bootloader output before USB Gadget Serial initializes.

### Recovery via adb
If device boots but is unresponsive:
```bash
# Wait for adb
adb devices

# Check if booted
adb shell getprop ro.build.version.release

# Reboot to bootloader
adb reboot bootloader
```

## References

- lk2nd project: https://github.com/msm8916-mainline/lk2nd
- Mobile NixOS: https://mobile-nixos.github.io/
- Motorola Titan specs: MSM8226 SoC, Adreno 305 GPU, 1GB RAM
- QCDT device tree format: Used by Qualcomm bootloaders for runtime DTB selection

## Notes

- USB Gadget Serial console is on ttyGS0 @ 115200 baud
- Device tree is selected at runtime by lk2nd from QCDT container
- Kernel params are passed via bootloader command line
- lk2nd stays in memory and manages device during boot
- All updates are done via single boot.img flash - no bootloader partition access needed
