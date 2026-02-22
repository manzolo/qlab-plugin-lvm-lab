#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"
echo ""; echo "${BOLD}Exercise 3 — Volume Groups${RESET}"; echo ""

ssh_vm "sudo pvcreate /dev/vdb /dev/vdc" >/dev/null 2>&1
assert "Create VG myvg" ssh_vm "sudo vgcreate myvg /dev/vdb /dev/vdc"

vgs=$(ssh_vm "sudo vgs")
assert_contains "VG myvg exists" "$vgs" "myvg"
assert_contains "VG has 2 PVs" "$vgs" "2"

ssh_vm "sudo pvcreate /dev/vdd" >/dev/null 2>&1
assert "Extend VG with /dev/vdd" ssh_vm "sudo vgextend myvg /dev/vdd"

vgs2=$(ssh_vm "sudo vgs")
assert_contains "VG now has 3 PVs" "$vgs2" "3"

# Cleanup
ssh_vm "sudo vgremove -f myvg; sudo pvremove /dev/vdb /dev/vdc /dev/vdd" >/dev/null 2>&1

report_results "Exercise 3"
