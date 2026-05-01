# AGENTS.md: Mobile NixOS - Titan (Moto G 2014) Port

## Project Goal

Port Mobile NixOS to Motorola Moto G 2014 (Titan, SoC MSM8226) with USB Gadget Serial console support (ttyGS0 @ 115200 baud) and mainline kernel (v6.16.12).

**Current Status**: 
- Mainline kernel v6.16.12 builds with USB Gadget Serial ✅
- lk2nd v16+: Boots to fastboot, all vibration checkpoints working, partition reading fixed ✅
- lk2nd device matching bug fixed (Titan DTB correctly passed to kernel) ✅
- Kernel early boot debugging workflow established via persistent RAM logging ✅

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
  - `kernel/kernel_ramlog.patch` - Injects early boot logging to persistent `.data` section
  - `kernel/kernel_head.patch` - Injects assembly memory traps in `head.S`

- **`devices/motorola-titan/`** - Vendor kernel variant (v3.4, for reference only)

- **`modules/`** - Mobile NixOS core (initrd, hardware quirks, system types)

- **`default.nix`** - Entry point; reads `--argstr device` and optional `local.nix`

## Key Configuration Details

### ⚠️ CRITICAL: lk2nd Integration in Device Config

The `devices/qcom-msm8226/default.nix` **must include** lk2nd second-stage bootloader in bootimg:

```nix
mobile.system.android.bootimg = {
  second = lib.mkDefault "${pkgs.lk2ndMsm8226}/lk2nd.img";
  flash = { ... };
  dt = lib.mkForce null;  # Use bootloader DTB, not kernel-generated
};
```

**Why**: Without `bootimg.second`, lk2nd is not embedded in boot image. Device will not have a working bootloader.
**Pattern**: Use `pkgs.lk2ndMsm8226` from the overlay (defined in `overlay/overlay.nix`). Do NOT manually callPackage the nix file.

### lk2nd Partition Fix (v16+)

**Problem v15 and earlier**: lk2nd hardcoded `ptn_name = "boot"`, but kernel is flashed to RECOVERY partition.
**Solution v16+**: Changed partition to `ptn_name = "recovery"` in `overlay/lk2nd/msm8226-debug-enhanced.patch`
- **Flash target**: Use `fastboot flash recovery mainline-boot-vXX.img` (not BOOT partition)

### USB Gadget Serial (Console)

- **Kernel**: Must have `CONFIG_USB_G_SERIAL=y` (builtin, not module)
- **Boot params**: `console=ttyGS0,115200` (no extra params needed)
- **Stage-1 USB features**: `[ "acm" "rndis" ]` - enables ACM serial in initrd

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
**Warning**: Wrong offsets cause early-boot crash before initrd.

## Automation and Testing

### Long-Running Builds with tmux

For builds that take 30-60 minutes (kernel cross-compile), always use tmux:

```bash
# Create named session (append bash -i to keep pane open if build crashes)
tmux new-session -d -s mainline-boot-vXX-build 'nix-build --argstr device qcom-msm8226 -A outputs.android-bootimg --max-jobs 4 -o mainline-boot-vXX.img; bash -i'

# Monitor live (non-blocking, read-only)
tmux capture-pane -t mainline-boot-vXX-build:0 -p | tail -n 30

# Clean up when done
tmux kill-session -t mainline-boot-vXX-build
```

**Key**: Use long descriptive session names so future agents know what's running. Always prefer `tmux capture-pane` over attaching.

### Patch Generation (CRITICAL)

- **Never write `.patch` files by hand or use `sed` blindly** - it causes malformed patches, context mismatches, and build failures.
- **Always use Python scripts** to parse the original source files, safely insert code, and generate standard patches via `diff -ruN a/ b/`.

## Early Kernel Debugging (Motorola Titan Quirks)

The device has no screen or hardware UART. We rely entirely on writing hex values to physical RAM in early ARM assembly or C, and reading them back after a forced reboot using `fastboot oem debug readl <address>`.

### Motorola RAM Wipe Behavior
- On a warm reboot, the Motorola primary bootloader wipes the first ~500MB of RAM (`0x10000000` to `0x20000000`).
- The upper edge of RAM (`0x2FF80000`) survives a hard reset.
- The `.data` section of the kernel (loaded at `0x00008000`) is bypassed by the wipe and is safe to use.

### 1. Assembly Traps in `head.S`
We can write raw hex values to physical memory `0x2FF80000` (and `+4`, `+8`) in `arch/arm/kernel/head.S` to prove the kernel is executing.
Example: Write `0x54535F31` ("1_ST") to `0x2FF80000`.

### 2. C Logging before MMU (The `.data` Strategy)
Writing to raw physical addresses like `0x2FF80000` inside C code (`init/main.c`) *after* the MMU is turned on will cause an instant fatal page fault if the address is not mapped in the early page tables.

**The fail-proof solution for early C logging:**
1. Declare a global logging buffer explicitly in the `.data` section:
   `__section(".data") char early_ramlog_buf[4096] = "MAGIC\n";`
2. Write logs to `early_ramlog_buf`. Since it is part of the kernel binary, it is guaranteed to be mapped early by `head.S`.
3. To read the log:
   - Extract the virtual address of `early_ramlog_buf` from the compiled `System.map`.
   - Calculate the physical address (for MSM8226: `phys_addr = virt_addr - 0xC0000000`).
   - Read the buffer in fastboot: `fastboot oem debug readl <phys_addr>`.

### Pre-reboot Protocol
1. Zero out target RAM addresses (optional but recommended): `fastboot oem debug writel <address> 0x00000000`
2. Flash kernel: `fastboot flash recovery mainline-boot-vXX.img`
3. Reboot: `fastboot reboot`
4. Wait 15-20 seconds. If `dmesg` / `journalctl` on host doesn't show a new USB connection, it hung.
5. Force reset: Hold Power + Vol Down for ~10 seconds.
6. Dump memory: `fastboot oem debug readl <address>`

## Useful Commands

```bash
# Check device in Fastboot
fastboot devices

# Flash to recovery partition
fastboot flash recovery mainline-boot.img

# Watch host for USB device appearing (meaning kernel USB initialized)
journalctl -k -f | grep -i "usb\|tty"
```

## References

- **Mobile NixOS docs**: https://mobile-nixos.github.io/
- **Kernel fork (msm8226-mainline)**: https://github.com/msm8226-mainline/linux (branch v6.16.12-msm8226)
