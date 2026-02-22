#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"
echo ""; echo "${BOLD}Exercise 2 — Physical Volumes${RESET}"; echo ""

assert "Create PV on /dev/vdb" ssh_vm "sudo pvcreate /dev/vdb"
assert "Create PV on /dev/vdc" ssh_vm "sudo pvcreate /dev/vdc"

pvs=$(ssh_vm "sudo pvs")
assert_contains "pvs shows /dev/vdb" "$pvs" "/dev/vdb"
assert_contains "pvs shows /dev/vdc" "$pvs" "/dev/vdc"

assert "Create PV on /dev/vdd" ssh_vm "sudo pvcreate /dev/vdd"
pvs2=$(ssh_vm "sudo pvs")
assert_contains "pvs shows /dev/vdd" "$pvs2" "/dev/vdd"

# Cleanup
ssh_vm "sudo pvremove /dev/vdb /dev/vdc /dev/vdd" >/dev/null 2>&1

report_results "Exercise 2"
