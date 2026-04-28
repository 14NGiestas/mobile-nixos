# AGENTS.md: Mobile NixOS - Titan (Moto G 2014) Port

## Project Goal

Port Mobile NixOS to Motorola Moto G 2014 (Titan, SoC MSM8226) with USB Gadget Serial console support (ttyGS0 @ 115200 baud) and mainline kernel (v6.16.12).

**Current Status**: Kernel builds with USB Gadget Serial enabled; testing serial console functionality.

## Build Command

```bash
nix-build --argstr device qcom-msm8226 -A outputs.android-bootimg --max-jobs 4 -o mainline-boot.img
```

This builds for the active device config at `devices/qcom-msm8226/default.nix`.

## Critical Project Structure

- **`devices/qcom-msm8226/`** - Active device config (Titan with mainline kernel v6.16.12)
  - `default.nix` - Device settings, kernel params, USB features
  - `kernel/default.nix` - Kernel builder (uses GitHub msm8226-mainline fork)
  - `kernel/config.armv7l` - Kernel config (CONFIG_USB_G_SERIAL=y is critical)

- **`devices/motorola-titan/`** - Vendor kernel variant (v3.4, for reference only)

- **`devices/families/`** - Shared SoC/vendor configs (not used for qcom-msm8226)

- **`modules/`** - Mobile NixOS core (initrd, hardware quirks, system types)

- **`default.nix`** - Entry point; reads `--argstr device` and optional `local.nix`

## Key Configuration Details

### USB Gadget Serial (Console)

- **Kernel**: Must have `CONFIG_USB_G_SERIAL=y` (builtin, not module)
- **Boot params**: `console=ttyGS0,115200` (no extra params needed)
- **Stage-1 USB features**: `[ "acm" "rndis" ]` - enables ACM serial in initrd
- **Bootloader cmdline override**: Device bootloader (Motorola) may override kernel params; only USB Gadget Serial matters for ttyGS0

### Device Offsets (Android bootimg)

```nix
mobile.system.android.bootimg.flash = {
  offset_base = "0x00000000";      # Critical: 0x00000000 for Motorola Titan
  offset_kernel = "0x00008000";    # Verified from CM-13 original bootimg
  offset_ramdisk = "0x01000000";   # Verified from CM-13 original bootimg
  offset_second = "0x00f00000";
  offset_tags = "0x00000100";
  pagesize = "2048";               # Verified from CM-13 original bootimg
};
```

**Source**: Verified against original CM-13 bootimg (kernel @ 0x8000, ramdisk @ 0x1000000, pagesize 2048)

**Warning**: Wrong offsets cause early-boot crash before initrd.

### DTB Handling

- **`mobile.system.android.bootimg.dt = lib.mkForce null`** - Use bootloader DTB, not kernel-generated
- Kernel-generated DTB was causing crashes; bootloader DTB (Motorola) works correctly

## Automation Scripts

### `monitor-and-flash.sh` (Main Automation)

Fully automated, no interaction needed:
1. Waits for kernel build to complete
2. Verifies boot image (checks `console=ttyGS0`)
3. Flashes via fastboot (requires device in Fastboot mode)
4. Reboots device
5. Waits for USB serial device (`/dev/ttyACM0` or similar)
6. Captures 10 seconds of boot output
7. Analyzes for kernel boot, USB Gadget Serial, user space, errors
8. Saves results to log

**Run**: `./monitor-and-flash.sh` (in background, ~40 minute total runtime)

**PID tracking**: `build-mainline-usb.pid` and `monitor-and-flash.pid`

**Status check**: `tail -f monitor-and-flash.log`

### `rebuild-mainline-usb.sh`

Builds kernel in background (spawns as subprocess):
```bash
./rebuild-mainline-usb.sh
# Runs: nix-build ... -o mainline-boot.img
# Log: build-mainline-usb.log
```

## Testing & Flashing

### Prerequisites
- Titan device connected via USB
- Device in **Fastboot mode** (accessible via `fastboot devices`)
- `fastboot` command available (from android-tools in shell.nix)

### Manual Flash (if needed)
```bash
fastboot flash boot mainline-boot.img
fastboot reboot
```

### Serial Console Access
Once booted with USB Gadget Serial:
```bash
screen /dev/ttyACM0 115200
# or
minicom -D /dev/ttyACM0 -b 115200
# or
picocom -b 115200 /dev/ttyACM0
```

## Common Pitfalls

1. **Kernel config mismatch**: If `CONFIG_USB_G_SERIAL` not in image, `strace -e openat` on boot will show no ttyGS0 device
   - **Fix**: Ensure `devices/qcom-msm8226/kernel/config.armv7l` has `CONFIG_USB_G_SERIAL=y`

2. **Wrong bootimg offsets**: Early-boot crash (before initrd vibrator kick)
   - **Fix**: Verify `offset_base = "0x00000000"` (not 0x80000000)

3. **DTB mismatch**: Kernel hangs with garbage on console
   - **Fix**: Keep `mobile.system.android.bootimg.dt = lib.mkForce null`

4. **Fastboot not found**: Build succeeds but flash step fails
   - **Fix**: `nix-shell` includes android-tools; run builds inside shell

5. **No USB serial device after reboot**: Device booted but `/dev/ttyACM0` missing
   - **Cause**: USB Gadget Serial not initialized in kernel
   - **Fix**: Check boot output capture; if kernel text not present, USB issue

## Git Workflow

- **Branch**: `development` (tracking `fork/development`)
- **Recent commits**: Device config updates, USB Gadget enablement
- **Commit only config changes** to devices/qcom-msm8226/ and kernel config; ignore build artifacts

## Nix Build Quirks

- **Cross-compilation**: Builds ARM (armv7l) binaries on x86_64 host (slower, 30-60 min for kernel)
- **No flake.nix**: Uses classic Nix expressions (nix-build, not nix build)
- **Kernel builder**: Custom wrapper in modules/; reads `configfile`, applies `postPatch`, handles cross-compile flags
- **Build artifacts**: Ignored by .gitignore (bootimg-result/, outputs/, pmaports-tmp/)

## Useful Commands

```bash
# Enter dev shell (includes android-tools, dtc, mkbootimg, etc.)
nix-shell

# Build for qcom-msm8226 device
nix-build --argstr device qcom-msm8226 -A outputs.android-bootimg -o result

# List available outputs
nix-build --argstr device qcom-msm8226 -A outputs --dry-run

# Check image contents
strings mainline-boot.img | grep console=
file mainline-boot.img

# Extract boot image for inspection
abootimg -x mainline-boot.img boot.cfg kernel initrd

# Check device in Fastboot
fastboot devices
```

## References

- **Mobile NixOS docs**: https://mobile-nixos.github.io/
- **Kernel fork (msm8226-mainline)**: https://github.com/msm8226-mainline/linux (branch v6.16.12-msm8226)
- **Related work**: postmarketOS msm8226 port
