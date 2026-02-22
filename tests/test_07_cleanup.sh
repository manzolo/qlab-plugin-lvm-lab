#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"
echo ""; echo "${BOLD}Exercise 7 — Cleanup${RESET}"; echo ""

# Clean up from previous tests first
ssh_vm "sudo umount /mnt/lvm 2>/dev/null; sudo umount /mnt/snap 2>/dev/null; sudo lvremove -f myvg 2>/dev/null; sudo vgremove -f myvg 2>/dev/null; sudo pvremove -ff /dev/vdb /dev/vdc 2>/dev/null; sudo wipefs -a /dev/vdb /dev/vdc 2>/dev/null; true" >/dev/null 2>&1 || true

# Create full stack
ssh_vm "sudo pvcreate -f /dev/vdb /dev/vdc && sudo vgcreate myvg /dev/vdb /dev/vdc && sudo lvcreate --yes -L 200M -n mylv myvg && sudo mkfs.ext4 -q /dev/myvg/mylv && sudo mkdir -p /mnt/lvm && sudo mount /dev/myvg/mylv /mnt/lvm" >/dev/null 2>&1

# Remove in order
assert "Unmount" ssh_vm "sudo umount /mnt/lvm"
assert "Remove LV" ssh_vm "sudo lvremove -f /dev/myvg/mylv"
assert "Remove VG" ssh_vm "sudo vgremove myvg"
assert "Remove PVs" ssh_vm "sudo pvremove /dev/vdb /dev/vdc"

# Verify clean
pvs=$(ssh_vm "sudo pvs 2>/dev/null" || echo "")
assert_not_contains "No PVs remain" "$pvs" "/dev/vdb|/dev/vdc"

vgs=$(ssh_vm "sudo vgs 2>/dev/null" || echo "")
assert_not_contains "No VGs remain" "$vgs" "myvg"

report_results "Exercise 7"
