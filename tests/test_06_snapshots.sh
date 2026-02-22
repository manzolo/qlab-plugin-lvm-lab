#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"
echo ""; echo "${BOLD}Exercise 6 — Snapshots${RESET}"; echo ""

# Check if dm-snapshot kernel module is available
if ! ssh_vm "sudo modprobe dm-snapshot 2>/dev/null" >/dev/null 2>&1; then
    log_info "dm-snapshot kernel module not available — skipping snapshot tests"
    log_info "(This is expected on KVM-optimized kernels)"
    PASS_COUNT=0
    FAIL_COUNT=0
    report_results "Exercise 6 (skipped)"
    exit 0
fi

# Clean up from previous tests
ssh_vm "sudo umount /mnt/lvm 2>/dev/null; sudo umount /mnt/snap 2>/dev/null; sudo lvremove -f myvg 2>/dev/null; sudo vgremove -f myvg 2>/dev/null; sudo pvremove -ff /dev/vdb /dev/vdc /dev/vdd 2>/dev/null; sudo wipefs -a /dev/vdb /dev/vdc /dev/vdd 2>/dev/null; true" >/dev/null 2>&1 || true

# Set up LVM stack
ssh_vm "sudo pvcreate -f /dev/vdb /dev/vdc /dev/vdd && sudo vgcreate myvg /dev/vdb /dev/vdc /dev/vdd && sudo lvcreate --yes -L 500M -n mylv myvg && sudo mkfs.ext4 -q /dev/myvg/mylv && sudo mkdir -p /mnt/lvm && sudo mount /dev/myvg/mylv /mnt/lvm && echo 'original data' | sudo tee /mnt/lvm/testfile.txt" >/dev/null 2>&1

assert "Create snapshot" ssh_vm "sudo lvcreate --yes -s -L 200M -n mysnap /dev/myvg/mylv"

lvs=$(ssh_vm "sudo lvs")
assert_contains "Snapshot appears in lvs" "$lvs" "mysnap"

ssh_vm "sudo mkdir -p /mnt/snap && sudo mount -o ro /dev/myvg/mysnap /mnt/snap" >/dev/null

snap_data=$(ssh_vm "cat /mnt/snap/testfile.txt")
assert_contains "Snapshot has original data" "$snap_data" "original data"

# Modify original
ssh_vm "echo 'modified' | sudo tee /mnt/lvm/testfile.txt" >/dev/null

# Snapshot still has old data
snap_data2=$(ssh_vm "cat /mnt/snap/testfile.txt")
assert_contains "Snapshot preserves old data after original modified" "$snap_data2" "original data"

# Cleanup
ssh_vm "sudo umount /mnt/snap /mnt/lvm; sudo lvremove -f myvg; sudo vgremove myvg; sudo pvremove -ff /dev/vdb /dev/vdc /dev/vdd" >/dev/null 2>&1 || true

report_results "Exercise 6"
