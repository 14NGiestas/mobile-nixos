#!/usr/bin/env bash
# Quick monitor script to check progress

MONITOR_LOG="/home/pauli/documents/code/titan/mobile-nixos/monitor-and-flash.log"
BUILD_LOG="/home/pauli/documents/code/titan/mobile-nixos/build-mainline-usb.log"
MONITOR_PID=$(cat /home/pauli/documents/code/titan/mobile-nixos/monitor-and-flash.pid 2>/dev/null)
BUILD_PID=$(cat /home/pauli/documents/code/titan/mobile-nixos/build-mainline-usb.pid 2>/dev/null)

echo "=== Build & Flash Monitor ==="
echo ""
echo "Build process:"
if ps -p $BUILD_PID > /dev/null 2>&1; then
    echo "  PID: $BUILD_PID - RUNNING"
else
    echo "  PID: $BUILD_PID - FINISHED"
fi

echo ""
echo "Monitor process:"
if ps -p $MONITOR_PID > /dev/null 2>&1; then
    echo "  PID: $MONITOR_PID - RUNNING (waiting for build)"
else
    echo "  PID: $MONITOR_PID - FINISHED"
fi

echo ""
echo "Last update from monitor:"
tail -3 "$MONITOR_LOG"

echo ""
echo "Last build activity:"
tail -1 "$BUILD_LOG"
