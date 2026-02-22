#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"
echo ""; echo "${BOLD}Exercise 1 — Storage Anatomy${RESET}"; echo ""

disks=$(ssh_vm "lsblk")
assert_contains "vdb disk is visible" "$disks" "vdb"
assert_contains "vdc disk is visible" "$disks" "vdc"
assert_contains "vdd disk is visible" "$disks" "vdd"
assert_contains "vde disk is visible" "$disks" "vde"

assert "lvm2 tools are installed (pvs)" ssh_vm "which pvs"
assert "lvm2 tools are installed (vgs)" ssh_vm "which vgs"
assert "lvm2 tools are installed (lvs)" ssh_vm "which lvs"

report_results "Exercise 1"
