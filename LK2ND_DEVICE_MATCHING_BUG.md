# lk2nd Device Matching Bug - Moto G 2014 (Titan)

## Problem

The Motorola bootloader passes `androidboot.device=titan` in the kernel cmdline,
but embeds an LG G Watch R DTB (apq8026-lg-lenok) that doesn't match Titan hardware.

lk2nd successfully loads the bootloader's lenok DTB and logs:
```
[1340] Detected device: LG G Watch R (compatible: lg,lenok)
[1350] Unexpected DTB selected by bootloader, need to override
```

But this "override" is just logging - lk2nd continues using the wrong DTB instead of
forcing selection from QCDT where Titan DTB exists.

## Root Cause

In `lk2nd/device/device.c`, the `parse_dtb()` function:

1. Loads the bootloader's embedded DTB
2. Reads the lk2nd node from it (gets lenok's compatible="lg,lenok")
3. Sets `lk2nd_dev.compatible` to this value
4. Later, `find_device_node()` looks for this compatible in QCDT

The issue: **lk2nd never checks if cmdline's `androidboot.device=titan` conflicts with
the loaded DTB's device type.**

## Solution

Add device matching validation before accepting the bootloader's DTB:

```c
static bool device_matches_dtb(const void *dtb, int lk2nd_node)
{
    // If cmdline says device=titan but DTB is lenok, reject bootloader DTB
    if (lk2nd_dev.device && lk2nd_dev.compatible) {
        // Use match_device_node() to validate match
        return match_device_node(dtb, lk2nd_node);
    }
    return true;  // No device name in cmdline, accept DTB
}
```

Then in `parse_dtb()`, check this before committing to the bootloader's DTB.

## PR Needed

File PR against msm8916-mainline/lk2nd:
- Add device validation before accepting bootloader DTB
- Fallback to QCDT if device mismatch detected
- Enables proper device detection for Motorola devices with wrong embedded DTBs

## Workaround (Current)

For Titan, we've fixed the Titan DTB to have correct SoC ID and board-id,
but can't force lk2nd to use it over the bootloader's lenok DTB due to this bug.
