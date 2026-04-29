#!/usr/bin/env bash

WORK_DIR="/home/pauli/documents/code/titan/mobile-nixos"
MONITOR_SCRIPT="$WORK_DIR/monitor-and-flash.sh"
MONITOR_LOG="$WORK_DIR/monitor-and-flash.log"
MONITOR_PID_FILE="$WORK_DIR/monitor-and-flash.pid"
FINAL_LOG="$WORK_DIR/automation-final-report.log"

log_msg() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $@" | tee -a "$FINAL_LOG"
}

log_msg "=== Starting full automation with timeout ==="
log_msg "Monitor script: $MONITOR_SCRIPT"
log_msg "Timeout: 3600 seconds (60 minutes)"
log_msg ""

# Run monitor-and-flash with 60 minute timeout
log_msg "Starting monitor-and-flash script..."
timeout 3600 bash "$MONITOR_SCRIPT" >> "$MONITOR_LOG" 2>&1 &
WAIT_PID=$!

# Wait for it to complete or timeout
if wait $WAIT_PID 2>/dev/null; then
    MONITOR_STATUS=$?
else
    MONITOR_STATUS=$?
fi

log_msg "Monitor script completed with status: $MONITOR_STATUS"
log_msg ""

# ============================================================================
# POST-AUTOMATION ANALYSIS
# ============================================================================

log_msg "=== Analyzing Results ==="
log_msg ""

if [ ! -f "$MONITOR_LOG" ]; then
    log_msg "ERROR: Monitor log not found"
    exit 1
fi

# Check if all phases completed
if grep -q "AUTOMATION COMPLETE" "$MONITOR_LOG"; then
    log_msg "✓ All automation phases completed successfully"
    AUTOMATION_SUCCESS=1
else
    log_msg "⚠ Automation did not complete all phases"
    AUTOMATION_SUCCESS=0
fi

# Extract results
if grep -q "USB serial device not found" "$MONITOR_LOG"; then
    log_msg "⚠ USB serial device was not detected"
    log_msg "   Check: Device connected? Correct drivers loaded?"
elif grep -q "✓ Found USB serial device" "$MONITOR_LOG"; then
    SERIAL_DEV=$(grep "✓ Found USB serial device" "$MONITOR_LOG" | tail -1 | awk '{print $NF}')
    log_msg "✓ USB serial device detected: $SERIAL_DEV"
fi

# Check boot success
if grep -q "SUCCESS: KERNEL BOOTED" "$MONITOR_LOG"; then
    log_msg "✓ Kernel booted successfully with USB Gadget Serial"
    BOOT_SUCCESS=1
else
    BOOT_SUCCESS=0
    log_msg "⚠ Boot status unclear from logs"
fi

# Extract test results
TEST_RESULTS=$(grep "Test Results:" "$MONITOR_LOG" | tail -1)
if [ ! -z "$TEST_RESULTS" ]; then
    log_msg "Results: $TEST_RESULTS"
fi

log_msg ""

# ============================================================================
# NEXT STEPS BASED ON RESULTS
# ============================================================================

log_msg "=== Next Steps ==="
log_msg ""

if [ $AUTOMATION_SUCCESS -eq 1 ] && [ $BOOT_SUCCESS -eq 1 ]; then
    log_msg "✓ FULL SUCCESS: Device is ready for testing"
    log_msg ""
    log_msg "Recommended next steps:"
    log_msg "  1. Connect to serial console:"
    if [ ! -z "$SERIAL_DEV" ]; then
        log_msg "     screen $SERIAL_DEV 115200"
    else
        log_msg "     screen /dev/ttyACM0 115200"
    fi
    log_msg "  2. Login and verify system:"
    log_msg "     - Check kernel version: uname -a"
    log_msg "     - Check USB Gadget: lsusb -v | grep Serial"
    log_msg "     - Test console stability: cat /dev/zero"
    
elif [ $AUTOMATION_SUCCESS -eq 1 ]; then
    log_msg "⚠ Automation completed but boot may not have completed"
    log_msg "  Next: Check serial console manually and review boot logs"
    
else
    log_msg "✗ Automation encountered issues"
    log_msg "  Next: Review monitor-and-flash.log for errors"
fi

log_msg ""
log_msg "=== AUTOMATION WRAPPER COMPLETE ==="
log_msg "Full report saved to: $FINAL_LOG"
log_msg ""

# Print last lines of monitor log
log_msg "=== Last 50 lines of monitor log ==="
tail -50 "$MONITOR_LOG" | sed 's/^/  /' | tee -a "$FINAL_LOG"

exit $MONITOR_STATUS
