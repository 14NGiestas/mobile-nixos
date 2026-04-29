#!/usr/bin/env bash

MONITOR_LOG="/home/pauli/documents/code/titan/mobile-nixos/monitor-and-flash.log"
MONITOR_PID=$(cat /home/pauli/documents/code/titan/mobile-nixos/monitor-and-flash.pid 2>/dev/null)

check_status() {
    if ! ps -p $MONITOR_PID > /dev/null 2>&1; then
        echo "=== MONITOR PROCESS COMPLETED ==="
        echo ""
        tail -50 "$MONITOR_LOG"
        return 0
    fi
    return 1
}

echo "Waiting for automation to complete..."
echo "Monitor PID: $MONITOR_PID"
echo ""

LAST_LINE=""
while true; do
    if check_status; then
        echo ""
        echo "Automation finished. Full log:"
        echo "  cat $MONITOR_LOG"
        exit 0
    fi
    
    CURRENT_LINE=$(tail -1 "$MONITOR_LOG" 2>/dev/null)
    if [ "$CURRENT_LINE" != "$LAST_LINE" ]; then
        echo "$(date '+%H:%M:%S') | $CURRENT_LINE"
        LAST_LINE="$CURRENT_LINE"
    fi
    
    sleep 5
done
