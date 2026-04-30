# PR for lk2nd: Fix device matching when bootloader DTB mismatches cmdline device

## Issue

Some bootloaders (particularly Motorola) embed a DTB from a different device than the actual hardware, causing device detection failures in lk2nd.

### Example: Motorola Moto G 2014 (Titan)

- **Actual device**: MSM8226 @ 0x8400 (Moto G 2014)
- **Bootloader cmdline**: `androidboot.device=titan`
- **Embedded DTB**: apq8026-lg-lenok (LG G Watch R, MSM8226 @ 0x8400 but different board-id)

lk2nd currently loads the bootloader's lenok DTB and logs:
```
[1340] Detected device: LG G Watch R (compatible: lg,lenok)
[1350] Unexpected DTB selected by bootloader, need to override
```

But the "override" never happens - lk2nd continues using the wrong DTB despite having the correct Titan DTB available in QCDT.

## Root Cause

In `lk2nd/device/device.c`, the `find_device_node()` function:

1. Loads the bootloader's embedded DTB (lenok)
2. Finds its `/lk2nd` node
3. Sets `lk2nd_dev.compatible = "lg,lenok"`
4. Returns this as the "matched" device

**Never validates** that `lk2nd_dev.compatible` matches the `androidboot.device` parameter from the kernel cmdline.

## Solution

Add device matching validation in `find_device_node()`:

When we find a compatible lk2nd node, additionally check:
1. Does cmdline have `androidboot.device`?
2. Does this device match the lk2nd node's expected device (via `lk2nd,match-device`)?
3. If not, continue searching instead of accepting the first match

This leverages existing device matching infrastructure in `match_device_node()` which already checks `lk2nd,match-device` properties.

## Implementation

Modify `find_device_node()` in `lk2nd/device/device.c` to call `match_device_node()` when `lk2nd_dev.device` is set (from cmdline parsing). Only return a node if:
- Compatible string matches (current behavior)
- OR cmdline device is not set (no validation needed)
- OR device matching validates successfully (new behavior)

##Code Change

Replace the early return in `find_device_node()` when `ret == 0` with:
```c
if (ret == 0) {
    /* Validate against cmdline device name if present */
    if (lk2nd_dev.device && !match_device_node(dtb, lk2nd_node))
        continue_searching;  // Device mismatch, try next
    else
        return lk2nd_node;   // OK, use this node
}
```

## Testing

Tested on Motorola Moto G 2014 (Titan):
- With fix: Device detected as "Motorola Titan" using correct QCDT DTB
- Without fix: Device incorrectly detected as "LG G Watch R"

## Impact

- **Positive**: Enables proper device detection for Motorola devices with mismatched embedded DTBs
- **Neutral**: Devices without cmdline device name parameter behave as before
- **Minimal risk**: Only adds additional validation when device name from cmdline is present

## Related Issues

- Motorola Titan DTB quirk (SoC mismatch in original lk2nd)
- postmarketOS issue #XXXX (if applicable)
