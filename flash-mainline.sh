#!/usr/bin/env bash
# Flash script to be used when mainline-boot.img is ready

IMG="/home/pauli/documents/code/titan/mobile-nixos/mainline-boot.img"

echo "=== Titan Fastboot Flash Script ==="
echo ""
echo "Prerequisites:"
echo "  - Titan device connected via USB"
echo "  - Device in Fastboot mode"
echo "  - fastboot command available"
echo ""
echo "Image to flash: $IMG"
echo ""

if [ ! -f "$IMG" ]; then
    echo "ERROR: Image not found at $IMG"
    exit 1
fi

echo "Image details:"
ls -lh "$IMG"
file "$IMG"
echo ""

echo "Checking fastboot connectivity..."
if ! fastboot devices | grep -q .; then
    echo "ERROR: No fastboot devices found!"
    echo "Make sure device is in Fastboot mode and connected via USB"
    exit 1
fi

echo "Connected devices:"
fastboot devices
echo ""

read -p "Continue with flash? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "=== Flashing boot partition ==="
    fastboot flash boot "$IMG"
    
    echo ""
    echo "=== Flash complete ==="
    echo "To boot the new image:"
    echo "  fastboot boot $IMG"
    echo "  OR reboot the device normally"
else
    echo "Aborted"
    exit 1
fi
