# AGENTS.md: Mobile NixOS - Titan (Moto G 2014) Port

## Project Goal

Port Mobile NixOS to Motorola Moto G 2014 (Titan, SoC MSM8226) with USB Gadget Serial console support (ttyGS0 @ 115200 baud) and mainline kernel (v6.16.12).

**Current Status**: 
- Mainline kernel v6.16.12 builds with USB Gadget Serial ✅
- lk2nd v34: Boots to fastboot, all vibration checkpoints working ✅
- **BLOCKER**: Discovered lk2nd device matching bug - uses bootloader's embedded LG Watch R DTB instead of Titan DTB from QCDT
- Titan DTB corrected (SoC MSM8226 + board-id) but can't be used until upstream lk2nd fix applied
- See LK2ND_DEVICE_MATCHING_BUG.md for details and proposed fix

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

### lk2nd Partition Fix (v16)

**Problem v15 and earlier**: lk2nd hardcoded `ptn_name = "boot"` in aboot.c:1628, but kernel is flashed to RECOVERY partition.
- Symptom: "Full party" vibrations (CP1→CP2→CP3→CP4→CP5 sequence repeating every 30s)
- Root cause: `[13400] ERROR: Invalid boot image header` - lk2nd reading wrong partition
- Device reboots every 30 seconds in infinite loop

**Solution v16**: Changed partition to `ptn_name = "recovery"` in `overlay/lk2nd/msm8226-debug-enhanced.patch`
- **Patch file**: `overlay/lk2nd/msm8226-debug-enhanced.patch` line 1628
- **Version bump**: Must increment version in `overlay/lk2nd/msm8226.nix` to bust Nix cache (currently v16)
- **Flash target**: Use `fastboot flash recovery mainline-boot-v16.img` (not BOOT partition)

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


## Automation and Testing

### Long-Running Builds with tmux

For builds that take 30-60 minutes (kernel cross-compile), always use tmux:

```bash
# Create named session
tmux new-session -d -s mobile-nixos-titan-build-v16-bootimg 'cd /home/pauli/documents/code/titan/mobile-nixos && nix-build --argstr device qcom-msm8226 -A outputs.android-bootimg --max-jobs 4 -o mainline-boot-v16.img'

# Monitor live (non-blocking, read-only)
watch -n 2 'tmux capture-pane -t mobile-nixos-titan-build-v16-bootimg:0 -p | tail -50'

# Or check once
tmux capture-pane -t mobile-nixos-titan-build-v16-bootimg:0 -p | tail -50

# Clean up when done
tmux kill-session -t mobile-nixos-titan-build-v16-bootimg
```

**Key**: Use long descriptive session names so future agents know what's running. Always prefer `tmux capture-pane` over attaching - it's read-only and won't interfere.

### General tmux Background Tasks

Use tmux to run long-lived background commands as background "tasks" like vite dev servers, commands with watch mode.  
Each task should be a tmux **session** that the agent can start, inspect, and stop via CLI.

ALWAYS give long and descriptive names for the sessions, so other agents know what they are for.

Run a background task (e.g. Vite dev server) without blocking:

```bash
tmux new-session -d -s project-name-vite-dev-port-8034 'cd /path/to/project && npm run dev --port 8034'
```

Every time you are about to start a new session, first check if there is one already.

List all background tasks (sessions):

```bash
tmux ls
```

You can assume sessions that do not have names were not started by you or agents so you can ignore them

Kill a background task:

```bash
tmux kill-session -t vite-dev
```

Never attach to a session. You are inside a non TTY terminal, meaning you instead will have to read the latest n logs instead.


Fetch the last N log lines for a task without attaching (returns immediately):

```bash
tmux capture-pane -t vite-dev:0 -S -100 -p
```

Example pattern for a coding agent:

1. Start a task:

   ```bash
   tmux new-session -d -s build 'cd /repo && npm run build'
   ```

2. Poll logs:

   ```bash
   tmux capture-pane -t build:0 -S -80 -p
   ```

3. List all running tasks:

   ```bash
   tmux ls
   ```

4. Stop a task when done:

   ```bash
   tmux kill-session -t build
   ```

Every time you are about to start a new session, first check if there is one already.

List all background tasks (sessions):

```bash
tmux ls
```

You can assume sessions that do not have names were not started by you or agents so you can ignore them

Kill a background task:

```bash
tmux kill-session -t vite-dev
```

Never attach to a session. You are inside a non TTY terminal, meaning you instead will have to read the latest n logs instead.


Fetch the last N log lines for a task without attaching (returns immediately):

```bash
tmux capture-pane -t vite-dev:0 -S -100 -p
```

Example pattern for a coding agent:

1. Start a task:

   ```bash
   tmux new-session -d -s build 'cd /repo && npm run build'
   ```

2. Poll logs:

   ```bash
   tmux capture-pane -t build:0 -S -80 -p
   ```

3. List all running tasks:

   ```bash
   tmux ls
   ```

4. Stop a task when done:

   ```bash
   tmux kill-session -t build
   ```

## Testing & Flashing

### Prerequisites
- Titan device connected via USB
- Device in **Fastboot mode** (accessible via `fastboot devices`)
- `fastboot` command available (from android-tools in shell.nix)

### Manual Flash (if needed)
```bash
# For v16 (with partition fix): flash to RECOVERY partition
fastboot flash recovery mainline-boot-v16.img
fastboot reboot

# Or if using old bootimg: flash to BOOT partition
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

1. **Missing `bootimg.second` in device config**: lk2nd not embedded in boot image
   - **Symptom**: Device has no bootloader, won't progress past primary bootloader
   - **Fix**: Ensure `devices/qcom-msm8226/default.nix` includes `mobile.system.android.bootimg.second = lib.mkDefault "${pkgs.lk2ndMsm8226}/lk2nd.img"`

2. **Boot loop with "full party" vibrations (every 30s)**: lk2nd reads from wrong partition
   - **Root cause**: lk2nd v15 and earlier hardcoded `ptn_name = "boot"`, but kernel is in RECOVERY partition
   - **Symptom**: All 5 vibration checkpoints (CP1-CP5) repeat every 30 seconds, then reboot
   - **Fix**: Use lk2nd v16+ with partition change, flash to RECOVERY: `fastboot flash recovery mainline-boot-vX.img`

3. **lk2nd_boot() causes hang**: Do NOT call lk2nd_boot() - it goes into infinite loop scanning mounted filesystems
   - **Fix**: Comment out the lk2nd_boot() call (see v15+ patches)

4. **Kernel config mismatch**: If `CONFIG_USB_G_SERIAL` not in image, `strace -e openat` on boot will show no ttyGS0 device
   - **Fix**: Ensure `devices/qcom-msm8226/kernel/config.armv7l` has `CONFIG_USB_G_SERIAL=y`

5. **Wrong bootimg offsets**: Early-boot crash (before initrd vibrator kick)
   - **Fix**: Verify `offset_base = "0x00000000"` (not 0x80000000)

6. **DTB mismatch**: Kernel hangs with garbage on console
   - **Fix**: Keep `mobile.system.android.bootimg.dt = lib.mkForce null`

7. **Fastboot not found**: Build succeeds but flash step fails
   - **Fix**: `nix-shell` includes android-tools; run builds inside shell

8. **No USB serial device after reboot**: Device booted but `/dev/ttyACM0` missing
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

### Vibration Checkpoint Diagnostics

lk2nd patch includes vibration checkpoint macros to trace boot flow on physical device (via vibration patterns):

- **VIB_CHECKPOINT_1()** - Single short pulse (aboot_init() START)
- **VIB_CHECKPOINT_2()** - Double pulse (lk2nd_init() completed)
- **VIB_CHECKPOINT_3()** - Triple pulse (normal_boot reached)
- **VIB_CHECKPOINT_4()** - Quad pulse (boot_linux_from_mmc() ENTRY)
- **VIB_CHECKPOINT_5()** - 5-pulse sequence (about to call boot_linux_from_mmc())

**Interpretation**:
- **All 5 checkpoints repeating every 30s** ("the full party"): lk2nd reads wrong partition, gets "Invalid boot image header", reboots. Use v16 with partition fix.
- **Stops at CP4**: lk2nd_boot() infinite loop (comment it out)
- **Single pulse repeating every 15s**: Kernel crashes early (check config/offsets)

Each pattern is distinctive and easy to identify during boot. If you see checkpoint patterns progress, you know which boot stage was reached before crash.

### Building lk2nd Binary Only (Fast)

When rebuilding ONLY lk2nd (e.g., for patch updates) without full bootimage:

1. **Update version** in `overlay/lk2nd/msm8226.nix`:
   ```nix
   version = "22.0-msm8226-titan-clean-vN";  # Increment N to bust cache
   ```

2. **Ensure patch updated** at `overlay/lk2nd/msm8226-debug-enhanced.patch` (critical: partition name at line 1628)

3. **Update device config** to reference via `pkgs.lk2ndMsm8226` (from overlay) in `devices/qcom-msm8226/default.nix`:
   ```nix
   mobile.system.android.bootimg.second = lib.mkDefault "${pkgs.lk2ndMsm8226}/lk2nd.img";
   ```

4. **Rebuild full bootimage** (kernel + lk2nd):
   ```bash
   nix-build --argstr device qcom-msm8226 -A outputs.android-bootimg --max-jobs 4 -o mainline-boot-vN.img
   ```

**Key**: Nix uses content-addressable paths. Version string MUST change to trigger rebuild - patch changes alone don't. Device config must explicitly reference `pkgs.lk2ndMsm8226` or build will use cached old version.

## lk2nd Device Matching Debug Workflow

**Goal**: Fix lk2nd device detection so it finds and boots Titan DTB instead of generic lenok (LG Watch R) DTB.

**Current Issue**: 
- Bootloader loads generic lenok DTB as root node 
- Cmdline has `androidboot.device=titan`
- lk2nd searches appended DTBs (QCDT) for `/lk2nd` subnode with `lk2nd,match-device="titan"`
- Search currently fails with `-1` (not found)

**Workflow** (all edits in `/tmp/lk2nd-v11-clean/`):

### 1. Add Debug Output to Matching Logic

Edit **`lk2nd/device/2nd/match.c`**:
- `lk2nd_device2nd_match_device_node()` - wrapper that iterates subnodes
  - Add: log which subnodes are being examined (`[1390]` prefix)
  - Add: count of total subnodes checked
- `match_device_node()` - per-node matching
  - Add: node name at start (`[1400]`)
  - Add: log each property checked (`lk2nd,match-device`, etc.)
  - Add: show actual vs expected values for mismatch
  - Add: final result (MATCHED or NO MATCH) (`[1406]`)

**Pattern**: Use unique numeric prefixes (1390-1410 range) for easy grep in boot logs.

### 2. Export Patch and Rebuild

```bash
# In /tmp/lk2nd-v11-clean/
git diff lk2nd/device/2nd/match.c > /tmp/match-debug.patch
git diff lk2nd/device/device.c >> /tmp/match-debug.patch
git diff lk2nd/device/2nd/device.c >> /tmp/match-debug.patch

# Copy to project overlay
cp /tmp/match-debug.patch /home/pauli/documents/code/titan/mobile-nixos/overlay/lk2nd/msm8226-debug-enhanced.patch

# Increment version in msm8226.nix to bust Nix cache
# Then build lk2nd binary only:
nix-build --argstr device qcom-msm8226 -A pkgs.lk2ndMsm8226 --max-jobs 4 -o lk2nd-vXX
```

**Key**: Use tmux for long builds:
```bash
tmux new-session -d -s lk2nd-vXX-build 'cd /home/pauli/documents/code/titan/mobile-nixos && nix-build --argstr device qcom-msm8226 -A pkgs.lk2ndMsm8226 --max-jobs 4 -o lk2nd-vXX'
tmux capture-pane -t lk2nd-vXX-build:0 -S -50 -p  # Check progress
```

### 3. Flash and Capture Boot Logs

```bash
nix-shell  # Enter dev environment

# Flash lk2nd binary to boot partition (for testing, not full bootimage)
fastboot flash boot lk2nd-vXX/lk2nd.img
fastboot reboot

# Capture debug output
fastboot oem log
fastboot get_staged /tmp/boot.log
cat /tmp/boot.log | grep "\[13"  # Filter to debug prefixes
```

### 4. Analyze Output

Expected log flow:
```
[1350] find_device_node: root has NO device requirement but cmdline has device=titan, searching subnodes
[1360] lk2nd_device2nd_match_device_node: searching subnodes of lk2nd_node=N
[1391] Examining subnode #1 (offset=M): 'msm8226-motorola-titan'
[1400] match_device_node: checking node 'msm8226-motorola-titan'
[1403]   lk2nd,match-device='titan' (len=5) vs dev='titan'
[1403]   OK: device matched
[1406] MATCHED node 'msm8226-motorola-titan'!
[1395] SUCCESS: Found matching device node at offset M
```

**If search fails** (node not found or property mismatch):
- Check if Titan DTB is actually in appended DTBs
- Verify `lk2nd,match-device` property exists in source DTS
- Check `match_string()` logic for edge cases

### 5. Iterate

- Modify source in `/tmp/lk2nd-v11-clean/`
- Re-export patch
- Increment version again
- Rebuild and test

**Don't touch**:
- Device config or kernel - only edit lk2nd source
- Nix files except version string

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
