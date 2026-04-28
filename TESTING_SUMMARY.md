# Titan (Moto G 2014) Mobile NixOS Port - Testing Summary

## Current Status (Apr 28, 2026)

### ✅ WORKING
- **Bootloader**: Motorola Fastboot (unlocked)
- **Bootimg offsets**: Verified correct (0x8000 kernel, 0x1000000 ramdisk, pagesize 2048)
- **CM-13 bootimg (v3.4 kernel)**: Boots reliably
- **motorola-titan Mobile NixOS build**: Compiles successfully, initrd starts (vibrator kick proves it)

### ❌ NOT WORKING
- **Mainline kernel v6.16.12**: Causes immediate boot failure (Fastboot reboot loop)
- **qcom-msm8226 device config with mainline**: Same failure
- **USB Gadget Serial (ttyGS0)**: Not available from v3.4 kernel
- **console=ttyGS0 kernel params**: Breaks motorola-titan boot
- **RNDIS network**: Doesn't reliably enumerate when booted

## Blockers

### 1. Console Access
**Problem**: No way to interact with running system
- v3.4 kernel doesn't have USB Gadget Serial compiled in
- Adding console params breaks boot
- No UART available
- Screen unavailable (embedded device)

**Attempted solutions**:
- ✗ Added console=ttyGS0 to motorola-titan config → breaks boot
- ✗ Modified CM-13 bootimg header with console param → doesn't activate
- ✗ Tried extracting/rebuilding bootimg with mkbootimg → lost critical data

### 2. Mainline Kernel Incompatibility
**Problem**: v6.16.12-msm8226 causes immediate reboot
- Might be device tree issue
- Might be memory layout incompatibility
- Might be missing critical early-boot driver

**Evidence**: Both qcom-msm8226 and motorola-titan configs fail with mainline

### 3. Network Unreliability
**Problem**: RNDIS interface doesn't reliably appear when booted
- motorola-titan config has networking.enable=true with hardcoded IPs
- Host sees USB device but networking doesn't work consistently
- No way to diagnose without console

## Recommendations

### Option A: Enable Serial Console (Recommended)
1. Recompile v3.4 kernel with USB_G_SERIAL=y (massive effort, GCC compatibility issues)
2. Once available, can SSH over USB network or use serial
3. Then can properly develop Mobile NixOS system

### Option B: Fix Mainline Kernel
1. Debug v6.16.12 early boot failure
2. Might require device tree fixes or bootloader tweaks
3. Would allow use of modern kernel with more features

### Option C: Use CM-13 Android as Base
1. Flash CM-13 as-is for stable boot
2. Focus on developing separate system partition
3. Not true Mobile NixOS but achieves device usability

### Option D: Network-only Debugging
1. Fix USB RNDIS enumeration
2. Boot motorola-titan and SSH in via network
3. Will require careful initrd configuration

## Files Generated

- `boot.img` - Original CM-13 bootimg (7.5MB, working)
- `boot-console.img` - Modified CM-13 with console param (doesn't help)
- `cm13-extract/` - Extracted kernel and ramdisk from CM-13
- `nixos-ramdisk/` - Mobile NixOS ramdisk for testing

## Next Steps

**Short term**: Get ANY console access to unblock development
**Long term**: Port to modern mainline kernel with full NixOS system

