# lvm-lab — LVM Disk Management Lab

[![QLab Plugin](https://img.shields.io/badge/QLab-Plugin-blue)](https://github.com/manzolo/qlab)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Linux-lightgrey)](https://github.com/manzolo/qlab)

A [QLab](https://github.com/manzolo/qlab) plugin that boots a virtual machine with 2 extra virtual disks for practicing LVM (Logical Volume Manager) operations.

## Objectives

- Understand LVM concepts: physical volumes, volume groups, logical volumes
- Create, resize, and remove LVM volumes
- Create and restore LVM snapshots
- Manage ext4 and XFS filesystems on LVM volumes

## How It Works

1. **Cloud image**: Downloads a minimal Ubuntu 22.04 cloud image (~250MB)
2. **Cloud-init**: Creates `user-data` with lvm2 and xfsprogs installation
3. **ISO generation**: Packs cloud-init files into a small ISO (cidata)
4. **Overlay disk**: Creates a COW disk on top of the base image (original stays untouched)
5. **Extra disks**: Creates 2 x 1GB virtual disks attached as `/dev/vdb` and `/dev/vdc`
6. **QEMU boot**: Starts the VM in background with SSH port forwarding and extra disks

## Credentials

- **Username:** `labuser`
- **Password:** `labpass`

## Ports

| Service | Host Port | VM Port |
|---------|-----------|---------|
| SSH     | dynamic   | 22      |

> All host ports are dynamically allocated. Use `qlab ports` to see the actual mappings.

## Disk Layout

| Device    | Size | Purpose             |
|-----------|------|---------------------|
| /dev/vdb  | 1GB  | Empty, for LVM      |
| /dev/vdc  | 1GB  | Empty, for LVM      |

## Usage

```bash
# Install the plugin
qlab install lvm-lab

# Run the lab
qlab run lvm-lab

# Wait ~60s for boot and package installation, then:

# Connect via SSH
qlab shell lvm-lab

# Inside the VM, try the LVM quick start:
#   sudo pvcreate /dev/vdb /dev/vdc
#   sudo vgcreate labvg /dev/vdb /dev/vdc
#   sudo lvcreate -L 800M -n data labvg
#   sudo mkfs.ext4 /dev/labvg/data
#   sudo mount /dev/labvg/data /mnt

# Stop the VM
qlab stop lvm-lab
```

## Exercises

> **New to LVM?** See the [Step-by-Step Guide](guide.md) for complete walkthroughs with detailed explanations.

| # | Exercise | What you'll do |
|---|----------|----------------|
| 1 | **Storage Anatomy** | Explore available disks and LVM tools |
| 2 | **Physical Volumes** | Initialize disks with `pvcreate`, inspect with `pvs` |
| 3 | **Volume Groups** | Create and manage VGs with `vgcreate` |
| 4 | **Logical Volumes** | Create LVs, format with ext4/xfs, mount |
| 5 | **Resizing** | Extend VGs and LVs online with `lvextend --resizefs` |
| 6 | **Snapshots** | Create LVM snapshots, modify data, rollback |
| 7 | **Cleanup** | Remove LVs, VGs, and PVs cleanly |

## Automated Tests

An automated test suite validates the exercises against a running VM:

```bash
# Start the lab first
qlab run lvm-lab
# Wait ~60s for cloud-init, then run all tests
qlab test lvm-lab
```

## Resetting

To start fresh, stop and re-run:

```bash
qlab stop lvm-lab
qlab run lvm-lab
```

Or reset the entire workspace:

```bash
qlab reset
```
