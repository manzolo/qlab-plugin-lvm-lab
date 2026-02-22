#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"
echo ""; echo "${BOLD}Exercise 5 — Resizing${RESET}"; echo ""

# Clean up from previous tests
ssh_vm "sudo umount /mnt/lvm 2>/dev/null; sudo umount /mnt/snap 2>/dev/null; sudo lvremove -f myvg 2>/dev/null; sudo vgremove -f myvg 2>/dev/null; sudo pvremove -ff /dev/vdb /dev/vdc /dev/vdd 2>/dev/null; sudo wipefs -a /dev/vdb /dev/vdc /dev/vdd 2>/dev/null; true" >/dev/null 2>&1 || true

# Set up LVM stack
ssh_vm "sudo pvcreate -f /dev/vdb /dev/vdc /dev/vdd && sudo vgcreate myvg /dev/vdb /dev/vdc /dev/vdd && sudo lvcreate --yes -L 500M -n mylv myvg && sudo mkfs.ext4 -q /dev/myvg/mylv && sudo mkdir -p /mnt/lvm && sudo mount /dev/myvg/mylv /mnt/lvm && echo 'before resize' | sudo tee /mnt/lvm/testfile.txt" >/dev/null 2>&1

# Get size before
size_before=$(ssh_vm "df -m /mnt/lvm | tail -1 | awk '{print \$2}'")

assert "Extend LV by 200M" ssh_vm "sudo lvextend -L +200M /dev/myvg/mylv"
assert "Resize filesystem" ssh_vm "sudo resize2fs /dev/myvg/mylv"

size_after=$(ssh_vm "df -m /mnt/lvm | tail -1 | awk '{print \$2}'")
assert_contains "Filesystem grew" "$(echo "$size_after > $size_before" | bc)" "1"

data=$(ssh_vm "cat /mnt/lvm/testfile.txt")
assert_contains "Data preserved after resize" "$data" "before resize"

# Cleanup
ssh_vm "sudo umount /mnt/lvm; sudo lvremove -f myvg; sudo vgremove myvg; sudo pvremove /dev/vdb /dev/vdc /dev/vdd" >/dev/null 2>&1 || true

report_results "Exercise 5"
