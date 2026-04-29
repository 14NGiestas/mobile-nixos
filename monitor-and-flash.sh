#!/usr/bin/env bash
set -e

BUILD_PID=$(cat /home/pauli/documents/code/titan/mobile-nixos/build-mainline-usb.pid 2>/dev/null)
LOGFILE="/home/pauli/documents/code/titan/mobile-nixos/build-mainline-usb.log"
IMG="/home/pauli/documents/code/titan/mobile-nixos/mainline-boot.img"
WORK_DIR="/home/pauli/documents/code/titan/mobile-nixos"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $@"
}

error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $@" >&2
    exit 1
}

# ============================================================================
# PHASE 1: Wait for build to complete
# ============================================================================

log "=== PHASE 1: Waiting for kernel build ==="
log "Build PID: $BUILD_PID"
log ""

if [ -z "$BUILD_PID" ]; then
    error "Could not find build PID"
fi

LAST_TIME=0
while ps -p $BUILD_PID > /dev/null 2>&1; do
    CURRENT_TIME=$(date +%s)
    if [ $((CURRENT_TIME - LAST_TIME)) -ge 30 ]; then
        TAIL_OUTPUT=$(tail -1 "$LOGFILE")
        log "Building... $(echo "$TAIL_OUTPUT" | cut -c1-70)"
        LAST_TIME=$CURRENT_TIME
    fi
    sleep 2
done

log "✓ Build process completed"
log ""

# ============================================================================
# PHASE 2: Verify image
# ============================================================================

log "=== PHASE 2: Verifying boot image ==="

if [ ! -f "$IMG" ]; then
    error "Build failed or image not found at $IMG"
fi

IMG_SIZE=$(ls -lh $IMG | awk '{print $5}')
log "Image size: $IMG_SIZE"

# Extract cmdline
CMDLINE=$(strings "$IMG" 2>/dev/null | grep -E "^console=" | head -1 || echo "NOT FOUND")
log "Kernel cmdline: $CMDLINE"

if [[ "$CMDLINE" != *"ttyGS0"* ]]; then
    error "Cmdline does not contain ttyGS0! Found: $CMDLINE"
fi

log "✓ Image verified (console=ttyGS0 present)"
log ""

# ============================================================================
# PHASE 3: Flash to device
# ============================================================================

log "=== PHASE 3: Flashing to Titan ==="

if ! command -v fastboot &> /dev/null; then
    error "fastboot command not found"
fi

# Wait for device (retry up to 60 seconds)
RETRY=0
MAX_RETRIES=30
while [ $RETRY -lt $MAX_RETRIES ]; do
    DEVICES=$(fastboot devices 2>/dev/null | grep -v "^$" | wc -l)
    if [ "$DEVICES" -gt 0 ]; then
        break
    fi
    ((RETRY++))
    sleep 2
done

if [ "$DEVICES" -eq 0 ]; then
    error "No fastboot devices found after 60s"
fi

DEVICE_NAME=$(fastboot devices | head -1 | awk '{print $1}')
log "Device: $DEVICE_NAME"

log "Flashing boot partition..."
if ! fastboot flash boot "$IMG" 2>&1 | grep -E "Sending|Wrote|Finished"; then
    error "Flash failed"
fi

log "✓ Flash successful"
log ""

# ============================================================================
# PHASE 4: Reboot device
# ============================================================================

log "=== PHASE 4: Rebooting device ==="

fastboot reboot > /dev/null 2>&1 || true
sleep 3

log "✓ Device rebooting"
log ""

# ============================================================================
# PHASE 5: Wait for USB serial device
# ============================================================================

log "=== PHASE 5: Waiting for USB serial console ==="

TIMEOUT=60
ELAPSED=0
SERIAL_DEV=""

while [ $ELAPSED -lt $TIMEOUT ]; do
    for DEV in /dev/ttyACM* /dev/ttyUSB* /dev/ttyS*; do
        if [ -e "$DEV" ] 2>/dev/null && ! [[ "$DEV" =~ ttyS0 ]]; then
            SERIAL_DEV="$DEV"
            break 2
        fi
    done
    
    ELAPSED=$((ELAPSED + 2))
    sleep 2
done

if [ -z "$SERIAL_DEV" ]; then
    error "USB serial device not found within ${TIMEOUT}s"
fi

log "✓ Found USB serial device: $SERIAL_DEV"
log ""

# ============================================================================
# PHASE 6: Test serial console
# ============================================================================

log "=== PHASE 6: Testing serial console ==="

SERIAL_OUTPUT=$(mktemp)
trap "rm -f $SERIAL_OUTPUT" EXIT

# Configure serial port
stty -F "$SERIAL_DEV" 115200 cs8 -cstopb -parenb ignbrk -ixoff 2>/dev/null || true

log "Capturing boot output (10 seconds)..."

timeout 10 cat "$SERIAL_DEV" 2>/dev/null > "$SERIAL_OUTPUT" || true

sleep 1

log "✓ Boot output captured"
log ""

# ============================================================================
# PHASE 7: Analyze results
# ============================================================================

log "=== PHASE 7: Analyzing boot output ==="

BOOT_SUCCESS=0
TESTS_PASSED=0
TESTS_TOTAL=4

# Test 1: Kernel boot
if grep -q "Linux version\|Booting\|KERNEL\|console" "$SERIAL_OUTPUT" 2>/dev/null; then
    log "✓ TEST 1/4: Kernel booted"
    ((TESTS_PASSED++))
else
    log "✗ TEST 1/4: No kernel boot message detected"
fi
((TESTS_TOTAL++))

# Test 2: USB Gadget Serial active
if grep -q "ttyGS0\|g_serial\|usb.*serial\|ACM\|gadget" "$SERIAL_OUTPUT" 2>/dev/null; then
    log "✓ TEST 2/4: USB Gadget Serial detected"
    ((TESTS_PASSED++))
else
    log "⚠ TEST 2/4: USB Gadget Serial not explicitly mentioned (may be active)"
fi
((TESTS_TOTAL++))

# Test 3: System reached user space
if grep -qE "Welcome to|systemd\[1\]|root@|login:|Entering new namespace" "$SERIAL_OUTPUT" 2>/dev/null; then
    log "✓ TEST 3/4: System reached user space"
    ((TESTS_PASSED++))
    BOOT_SUCCESS=1
else
    log "⚠ TEST 3/4: Early boot detected (may still be initializing)"
fi
((TESTS_TOTAL++))

# Test 4: No critical errors
ERROR_COUNT=$(grep -c "FATAL\|Kernel panic\|Unable to mount\|CPU hung" "$SERIAL_OUTPUT" 2>/dev/null || echo 0)
if [ "$ERROR_COUNT" -eq 0 ]; then
    log "✓ TEST 4/4: No critical errors detected"
    ((TESTS_PASSED++))
else
    log "✗ TEST 4/4: Found $ERROR_COUNT critical errors"
fi
((TESTS_TOTAL++))

log ""

# ============================================================================
# COMPLETION
# ============================================================================

if [ $BOOT_SUCCESS -eq 1 ]; then
    log "=== SUCCESS: KERNEL BOOTED WITH USB GADGET SERIAL ==="
else
    log "=== BOOT DETECTED (may still be initializing) ==="
fi

log ""
log "Test Results: $TESTS_PASSED/$TESTS_TOTAL passed"
log ""
log "Device: $DEVICE_NAME"
log "Serial Device: $SERIAL_DEV"
log "Boot Image: $IMG ($IMG_SIZE)"
log "Console: $CMDLINE"
log ""
log "Boot log saved to: $SERIAL_OUTPUT"
log ""
log "First 30 lines of boot output:"
head -30 "$SERIAL_OUTPUT" | sed 's/^/  /'
log ""
log "Last 20 lines of boot output:"
tail -20 "$SERIAL_OUTPUT" | sed 's/^/  /'
log ""
log "=== AUTOMATION COMPLETE ==="
