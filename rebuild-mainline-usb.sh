#!/usr/bin/env bash
set -e

LOGFILE="/home/pauli/documents/code/titan/mobile-nixos/build-mainline-usb.log"
PIDFILE="/home/pauli/documents/code/titan/mobile-nixos/build-mainline-usb.pid"

echo "=== Starting mainline rebuild in background ==="
echo "Device: qcom-msm8226"
echo "Log file: $LOGFILE"
echo "PID file: $PIDFILE"
echo ""

cd /home/pauli/documents/code/titan/mobile-nixos

# Remove old files
rm -f mainline-boot.img

# Start build in background
(
  echo "Build started at $(date)"
  echo "Device: qcom-msm8226"
  echo ""
  
  nix-build --argstr device qcom-msm8226 \
    -A outputs.android-bootimg \
    --max-jobs 4 \
    -o mainline-boot.img 2>&1
  
  BUILD_STATUS=$?
  echo ""
  echo "Build finished at $(date) with status: $BUILD_STATUS"
  
  if [ $BUILD_STATUS -eq 0 ]; then
    echo "SUCCESS! Image ready:"
    ls -lh mainline-boot.img
  else
    echo "FAILED! Build returned status $BUILD_STATUS"
  fi
) > "$LOGFILE" 2>&1 &

BUILD_PID=$!
echo $BUILD_PID > "$PIDFILE"
echo "Build process spawned with PID: $BUILD_PID"
echo ""
echo "Monitor with: tail -f $LOGFILE"
echo "Check status with: ps -p $BUILD_PID"
