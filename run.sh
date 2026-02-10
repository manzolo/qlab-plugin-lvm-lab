#!/usr/bin/env bash
# lvm-lab run script — boots a VM with extra virtual disks for LVM practice

set -euo pipefail

PLUGIN_NAME="lvm-lab"
SSH_PORT=2232
DISK_SIZE="1G"
DISK_COUNT=4

echo "============================================="
echo "  lvm-lab: LVM Disk Management Lab"
echo "============================================="
echo ""
echo "  This lab demonstrates:"
echo "    1. LVM concepts: physical volumes, volume groups, logical volumes"
echo "    2. Creating and resizing logical volumes"
echo "    3. LVM snapshots for backups"
echo "    4. Filesystem operations on LVM volumes"
echo ""
echo "  The VM will have ${DISK_COUNT} extra virtual disks (${DISK_SIZE} each)"
echo "  available as /dev/vdb, /dev/vdc, /dev/vdd and /dev/vde for LVM operations."
echo ""

# Source QLab core libraries
if [[ -z "${QLAB_ROOT:-}" ]]; then
    echo "ERROR: QLAB_ROOT not set. Run this plugin via 'qlab run ${PLUGIN_NAME}'."
    exit 1
fi

for lib_file in "$QLAB_ROOT"/lib/*.bash; do
    # shellcheck source=/dev/null
    [[ -f "$lib_file" ]] && source "$lib_file"
done

# Configuration
WORKSPACE_DIR="${WORKSPACE_DIR:-.qlab}"
LAB_DIR="lab"
IMAGE_DIR="$WORKSPACE_DIR/images"
CLOUD_IMAGE_URL=$(get_config CLOUD_IMAGE_URL "https://cloud-images.ubuntu.com/minimal/releases/jammy/release/ubuntu-22.04-minimal-cloudimg-amd64.img")
CLOUD_IMAGE_FILE="$IMAGE_DIR/ubuntu-22.04-minimal-cloudimg-amd64.img"
MEMORY="${QLAB_MEMORY:-$(get_config DEFAULT_MEMORY 1024)}"

# Ensure directories exist
mkdir -p "$LAB_DIR" "$IMAGE_DIR"

# Step 1: Download cloud image if not present
# Cloud images are pre-built OS images designed for cloud environments.
# They are minimal and expect cloud-init to configure them on first boot.
info "Step 1: Cloud image"
if [[ -f "$CLOUD_IMAGE_FILE" ]]; then
    success "Cloud image already downloaded: $CLOUD_IMAGE_FILE"
else
    echo ""
    echo "  Cloud images are pre-built OS images designed for cloud environments."
    echo "  They are minimal and expect cloud-init to configure them on first boot."
    echo ""
    info "Downloading Ubuntu cloud image..."
    echo "  URL: $CLOUD_IMAGE_URL"
    echo "  This may take a few minutes depending on your connection."
    echo ""
    check_dependency curl || exit 1
    curl -L -o "$CLOUD_IMAGE_FILE" "$CLOUD_IMAGE_URL" || {
        error "Failed to download cloud image."
        echo "  Check your internet connection and try again."
        exit 1
    }
    success "Cloud image downloaded: $CLOUD_IMAGE_FILE"
fi
echo ""

# Step 2: Create cloud-init configuration
# cloud-init reads user-data to configure the VM on first boot:
#   - creates users, installs packages, writes config files, runs commands
info "Step 2: Cloud-init configuration"
echo ""
echo "  cloud-init will:"
echo "    - Create a user 'labuser' with SSH access"
echo "    - Install lvm2 and xfsprogs packages"
echo "    - The extra disks will be available as raw block devices"
echo ""

cat > "$LAB_DIR/user-data" <<'USERDATA'
#cloud-config
hostname: lvm-lab
package_update: true
users:
  - name: labuser
    plain_text_passwd: labpass
    lock_passwd: false
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ssh_authorized_keys:
      - "__QLAB_SSH_PUB_KEY__"
ssh_pwauth: true
packages:
  - lvm2
  - xfsprogs
write_files:
  - path: /etc/profile.d/cloud-init-status.sh
    permissions: '0755'
    content: |
      #!/bin/bash
      if command -v cloud-init >/dev/null 2>&1; then
        status=$(cloud-init status 2>/dev/null)
        if echo "$status" | grep -q "running"; then
          printf '\033[1;33m'
          echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
          echo "  Cloud-init is still running..."
          echo "  Some packages and services may not be ready yet."
          echo "  Run 'cloud-init status --wait' to wait for completion."
          echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
          printf '\033[0m\n'
        fi
      fi
  - path: /etc/motd.raw
    content: |
      \033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m
        \033[1;32mlvm-lab\033[0m — \033[1mLVM Disk Management Lab\033[0m
      \033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m

        \033[1;33mDisks:\033[0m  /dev/vdb  /dev/vdc  /dev/vdd  /dev/vde  (1G each, empty)

        \033[1;33mQuick start — try these commands in order:\033[0m

        \033[1;35m1.\033[0m \033[0;32msudo pvcreate /dev/vdb /dev/vdc /dev/vdd /dev/vde\033[0m
        \033[1;35m2.\033[0m \033[0;32msudo vgcreate labvg /dev/vdb /dev/vdc /dev/vdd /dev/vde\033[0m
        \033[1;35m3.\033[0m \033[0;32msudo lvcreate -L 2G -n data labvg\033[0m
        \033[1;35m4.\033[0m \033[0;32msudo mkfs.ext4 /dev/labvg/data\033[0m
        \033[1;35m5.\033[0m \033[0;32msudo mount /dev/labvg/data /mnt\033[0m
        \033[1;35m6.\033[0m \033[0;32msudo lvextend -L +1G --resizefs /dev/labvg/data\033[0m

        \033[1;33mInspect:\033[0m
          \033[0;32mlsblk\033[0m   \033[0;32mpvs\033[0m   \033[0;32mvgs\033[0m   \033[0;32mlvs\033[0m   \033[0;32mdf -h /mnt\033[0m

        \033[1;33mSnapshots:\033[0m
          \033[0;32msudo lvcreate -L 100M -s -n snap1 /dev/labvg/data\033[0m
          \033[0;32msudo lvs\033[0m             \033[2m# see snapshot usage\033[0m

        \033[1;33mCredentials:\033[0m  \033[1;36mlabuser\033[0m / \033[1;36mlabpass\033[0m
        \033[1;33mExit:\033[0m         type '\033[1;31mexit\033[0m'

      \033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m


runcmd:
  - chmod -x /etc/update-motd.d/*
  - sed -i 's/^#\?PrintMotd.*/PrintMotd yes/' /etc/ssh/sshd_config
  - sed -i 's/^session.*pam_motd.*/# &/' /etc/pam.d/sshd
  - printf '%b\n' "$(cat /etc/motd.raw)" > /etc/motd
  - rm -f /etc/motd.raw
  - systemctl restart sshd
  - echo "=== lvm-lab VM is ready! ==="
USERDATA

# Inject the SSH public key into user-data
sed -i "s|__QLAB_SSH_PUB_KEY__|${QLAB_SSH_PUB_KEY:-}|g" "$LAB_DIR/user-data"

cat > "$LAB_DIR/meta-data" <<METADATA
instance-id: ${PLUGIN_NAME}-001
local-hostname: ${PLUGIN_NAME}
METADATA

success "Created cloud-init files in $LAB_DIR/"
echo ""

# Step 3: Generate cloud-init ISO
# QEMU reads cloud-init data from a small ISO image (CD-ROM).
# We use genisoimage to create it with the 'cidata' volume label.
info "Step 3: Cloud-init ISO"
echo ""
echo "  QEMU reads cloud-init data from a small ISO image (CD-ROM)."
echo "  We use genisoimage to create it with the 'cidata' volume label."
echo ""

CIDATA_ISO="$LAB_DIR/cidata.iso"
check_dependency genisoimage || {
    warn "genisoimage not found. Install it with: sudo apt install genisoimage"
    exit 1
}
genisoimage -output "$CIDATA_ISO" -volid cidata -joliet -rock \
    "$LAB_DIR/user-data" "$LAB_DIR/meta-data" 2>/dev/null
success "Created cloud-init ISO: $CIDATA_ISO"
echo ""

# Step 4: Create overlay disk
# An overlay disk uses copy-on-write (COW) on top of the base image.
# The original cloud image stays untouched; all writes go to the overlay.
info "Step 4: Overlay disk"
echo ""
echo "  An overlay disk uses copy-on-write (COW) on top of the base image."
echo "  This means:"
echo "    - The original cloud image stays untouched"
echo "    - All writes go to the overlay file"
echo "    - You can reset the lab by deleting the overlay"
echo ""

OVERLAY_DISK="$LAB_DIR/${PLUGIN_NAME}-disk.qcow2"
if [[ -f "$OVERLAY_DISK" ]]; then
    info "Removing previous overlay disk..."
    rm -f "$OVERLAY_DISK"
fi
create_overlay "$CLOUD_IMAGE_FILE" "$OVERLAY_DISK" "${QLAB_DISK_SIZE:-}"
echo ""

# Step 5: Create extra virtual disks for LVM practice
# These disks will appear as /dev/vdb and /dev/vdc inside the VM,
# ready for pvcreate, vgcreate, lvcreate operations.
info "Step 5: Extra virtual disks (${DISK_COUNT} x ${DISK_SIZE})"
echo ""
echo "  These disks will appear as /dev/vdb, /dev/vdc, /dev/vdd and /dev/vde"
echo "  inside the VM, ready for LVM operations."
echo ""

DRIVE_ARGS=()
for i in $(seq 1 "$DISK_COUNT"); do
    disk="$LAB_DIR/lvm-disk${i}.qcow2"
    if [[ -f "$disk" ]]; then rm -f "$disk"; fi
    create_disk "$disk" "$DISK_SIZE"
    DRIVE_ARGS+=(-drive "file=$disk,format=qcow2,if=virtio")
done
echo ""

# Step 6: Boot the VM in background
info "Step 6: Starting VM in background"
echo ""
echo "  The VM will run in background with:"
echo "    - Serial output logged to .qlab/logs/$PLUGIN_NAME.log"
echo "    - SSH access on port $SSH_PORT"
echo "    - ${DISK_COUNT} extra disks attached for LVM practice"
echo ""

start_vm "$OVERLAY_DISK" "$CIDATA_ISO" "$MEMORY" "$PLUGIN_NAME" "$SSH_PORT" \
    "${DRIVE_ARGS[@]}"

echo ""
echo "============================================="
echo "  lvm-lab: VM is booting"
echo "============================================="
echo ""
echo "  Credentials:"
echo "    Username: labuser"
echo "    Password: labpass"
echo ""
echo "  Connect via SSH (wait ~60s for boot + package install):"
echo "    qlab shell ${PLUGIN_NAME}"
echo ""
echo "  Disk layout inside the VM:"
echo "    /dev/vdb  (${DISK_SIZE}) — empty, for LVM"
echo "    /dev/vdc  (${DISK_SIZE}) — empty, for LVM"
echo "    /dev/vdd  (${DISK_SIZE}) — empty, for LVM"
echo "    /dev/vde  (${DISK_SIZE}) — empty, for LVM"
echo ""
echo "  View boot log:"
echo "    qlab log ${PLUGIN_NAME}"
echo ""
echo "  Stop VM:"
echo "    qlab stop ${PLUGIN_NAME}"
echo ""
echo "  Tip: override resources with environment variables:"
echo "    QLAB_MEMORY=4096 QLAB_DISK_SIZE=30G qlab run ${PLUGIN_NAME}"
echo "============================================="
