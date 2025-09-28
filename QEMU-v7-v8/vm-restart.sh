#!/bin/bash
VMID="$1"

sleep 2

if qm status "$VMID" | grep -q "status: running"; then
    qm stop "$VMID"
    sleep 2
    qm start "$VMID"
fi