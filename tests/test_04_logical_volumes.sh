#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"
echo ""; echo "${BOLD}Exercise 4 — Logical Volumes${RESET}"; echo ""

# Clean and setup LVM stack
ssh_vm "sudo umount /mnt/lvm 2>/dev/null; sudo lvremove -f myvg 2>/dev/null; sudo vgremove -f myvg 2>/dev/null; sudo pvremove -ff /dev/vdb /dev/vdc /dev/vdd 2>/dev/null; sudo wipefs -a /dev/vdb /dev/vdc /dev/vdd 2>/dev/null; true" >/dev/null 2>&1 || true
ssh_vm "sudo pvcreate -f /dev/vdb /dev/vdc /dev/vdd && sudo vgcreate myvg /dev/vdb /dev/vdc /dev/vdd" >/dev/null 2>&1

assert "Create LV mylv (500M)" ssh_vm "sudo lvcreate --yes -L 500M -n mylv myvg"

lvs=$(ssh_vm "sudo lvs")
assert_contains "LV mylv exists" "$lvs" "mylv"

assert "Create ext4 filesystem" ssh_vm "sudo mkfs.ext4 -q /dev/myvg/mylv"
ssh_vm "sudo mkdir -p /mnt/lvm && sudo mount /dev/myvg/mylv /mnt/lvm" >/dev/null
assert "Write data to LV" ssh_vm "echo 'LVM test' | sudo tee /mnt/lvm/testfile.txt"

data=$(ssh_vm "cat /mnt/lvm/testfile.txt")
assert_contains "Data is readable" "$data" "LVM test"

df_out=$(ssh_vm "df -h /mnt/lvm")
assert_contains "Filesystem is mounted" "$df_out" "/mnt/lvm"

# Cleanup
ssh_vm "sudo umount /mnt/lvm; sudo lvremove -f myvg; sudo vgremove myvg; sudo pvremove -ff /dev/vdb /dev/vdc /dev/vdd" >/dev/null 2>&1 || true

report_results "Exercise 4"
