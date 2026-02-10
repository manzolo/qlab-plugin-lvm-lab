#!/usr/bin/env bash
# lvm-lab install script

set -euo pipefail

echo ""
echo "  [lvm-lab] Installing..."
echo ""
echo "  This plugin demonstrates LVM (Logical Volume Manager) inside"
echo "  a QEMU VM with 2 extra virtual disks for hands-on practice."
echo ""
echo "  What you will learn:"
echo "    - How to create physical volumes (PV), volume groups (VG), and logical volumes (LV)"
echo "    - How to resize logical volumes online"
echo "    - How to create and restore LVM snapshots"
echo "    - How to manage filesystems on LVM volumes"
echo ""

# Create lab working directory
mkdir -p lab

# Check for required tools
echo "  Checking dependencies..."
local_ok=true
for cmd in qemu-system-x86_64 qemu-img genisoimage curl; do
    if command -v "$cmd" &>/dev/null; then
        echo "    [OK] $cmd"
    else
        echo "    [!!] $cmd — not found (install before running)"
        local_ok=false
    fi
done

if [[ "$local_ok" == true ]]; then
    echo ""
    echo "  All dependencies are available."
else
    echo ""
    echo "  Some dependencies are missing. Install them with:"
    echo "    sudo apt install qemu-kvm qemu-utils genisoimage curl"
fi

echo ""
echo "  [lvm-lab] Installation complete."
echo "  Run with: qlab run lvm-lab"
