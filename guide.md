# LVM Lab — Step-by-Step Guide

This guide walks you through **LVM (Logical Volume Manager)**, the flexible storage management layer used on most Linux servers. LVM sits between physical disks and filesystems, allowing you to resize, snapshot, and reorganize storage without downtime.

By the end of this lab you will understand the LVM stack (PV → VG → LV), create and resize logical volumes, take snapshots for backups, and manage storage confidently.

## Prerequisites

Start the lab and wait for the VM to boot (~60 seconds):

```bash
qlab run lvm-lab
```

```bash
qlab shell lvm-lab
cloud-init status --wait
```

## Credentials

- **Username:** `labuser`
- **Password:** `labpass`

## Lab Environment

The VM has **4 extra virtual disks** (1 GB each) for practice:
- `/dev/vdb`, `/dev/vdc`, `/dev/vdd`, `/dev/vde`

These are empty raw block devices — no partitions, no filesystems.

---

## Exercise 01 — Storage Anatomy

**Goal:** Understand the LVM stack before creating anything.

Traditional partitions are rigid — once created, they're hard to resize. LVM adds a flexible layer: Physical Volumes (PVs) are grouped into Volume Groups (VGs), and Logical Volumes (LVs) are carved from VGs. You can add or remove PVs, resize LVs, and even move data between disks — all while the system is running.

### 1.1 List block devices

```bash
lsblk
```

**Expected output:**
```
NAME   MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
vda    ...      0   ...  0 disk
├─vda1 ...      0   ...  0 part /
vdb    ...      0    1G  0 disk
vdc    ...      0    1G  0 disk
vdd    ...      0    1G  0 disk
vde    ...      0    1G  0 disk
```

### 1.2 Verify LVM tools are installed

```bash
which pvs vgs lvs
```

### 1.3 Check current LVM status (should be empty)

```bash
sudo pvs
sudo vgs
sudo lvs
```

All three should return empty tables — no LVM objects exist yet.

**Verification:** You can see 4 extra disks (vdb-vde) and LVM tools are available.

---

## Exercise 02 — Physical Volumes

**Goal:** Initialize disks for use with LVM.

A Physical Volume (PV) is an LVM-initialized disk or partition. The `pvcreate` command writes LVM metadata to the disk, marking it as available for LVM. Without this step, LVM can't use the disk.

### 2.1 Create PVs on two disks

The `-f` flag forces creation, overwriting any existing signatures on the disks (e.g., old filesystem or LVM metadata):

```bash
sudo pvcreate -f /dev/vdb /dev/vdc
```

**Expected output:**
```
  Physical volume "/dev/vdb" successfully created.
  Physical volume "/dev/vdc" successfully created.
```

### 2.2 List PVs

```bash
sudo pvs
```

**Expected output:**
```
  PV         VG   Fmt  Attr PSize    PFree
  /dev/vdb        lvm2 ---  1020.00m 1020.00m
  /dev/vdc        lvm2 ---  1020.00m 1020.00m
```

### 2.3 Detailed PV info

```bash
sudo pvdisplay /dev/vdb
```

Notice "PE Size" (Physical Extent) — this is the minimum allocation unit, typically 4 MB.

**Verification:** `sudo pvs` shows two PVs with ~1 GB each.

---

## Exercise 03 — Volume Groups

**Goal:** Pool PVs into a Volume Group.

A Volume Group combines one or more PVs into a single storage pool. LVs are allocated from this pool. Think of it like combining several USB drives into one big virtual drive.

### 3.1 Create a Volume Group

```bash
sudo vgcreate myvg /dev/vdb /dev/vdc
```

**Expected output:**
```
  Volume group "myvg" successfully created
```

### 3.2 Check VG details

```bash
sudo vgs
```

**Expected output:**
```
  VG   #PV #LV #SN Attr   VSize VFree
  myvg   2   0   0 wz--n- 1.99g 1.99g
```

### 3.3 Add a third PV

```bash
sudo pvcreate -f /dev/vdd
sudo vgextend myvg /dev/vdd
```

### 3.4 Verify the VG grew

```bash
sudo vgs
```

VSize should now be ~3 GB (three 1 GB disks).

**Verification:** `sudo vgs` shows myvg with 3 PVs and ~3 GB.

---

## Exercise 04 — Logical Volumes

**Goal:** Create, format, mount, and use a Logical Volume.

Logical Volumes are the LVM equivalent of partitions — but flexible. You can create them, resize them, and even move them between disks while they're mounted.

### 4.1 Create an LV

The `--yes` flag auto-confirms any prompts (e.g., wiping existing signatures):

```bash
sudo lvcreate --yes -L 500M -n mylv myvg
```

### 4.2 Check LV status

```bash
sudo lvs
```

**Expected output:**
```
  LV   VG   Attr       LSize   ...
  mylv myvg -wi-a----- 500.00m
```

### 4.3 Create a filesystem

```bash
sudo mkfs.ext4 /dev/myvg/mylv
```

### 4.4 Mount and use

```bash
sudo mkdir -p /mnt/lvm
sudo mount /dev/myvg/mylv /mnt/lvm
echo "Hello LVM" | sudo tee /mnt/lvm/testfile.txt
cat /mnt/lvm/testfile.txt
```

**Expected output:**
```
Hello LVM
```

### 4.5 Check disk usage

```bash
df -h /mnt/lvm
```

### 4.6 Create a second LV with XFS

```bash
sudo lvcreate --yes -L 300M -n xfslv myvg
sudo mkfs.xfs /dev/myvg/xfslv
sudo mkdir -p /mnt/xfs
sudo mount /dev/myvg/xfslv /mnt/xfs
df -h /mnt/xfs
```

**Verification:** Both LVs are mounted and usable, data can be written and read.

---

## Exercise 05 — Resizing

**Goal:** Extend an LV and its filesystem online (without unmounting).

One of LVM's biggest advantages: you can grow a filesystem while it's in use. This means zero downtime for adding storage — critical for production servers.

### 5.1 Check current size

```bash
df -h /mnt/lvm
```

### 5.2 Extend the LV

```bash
sudo lvextend -L +200M /dev/myvg/mylv
```

### 5.3 Resize the filesystem

```bash
sudo resize2fs /dev/myvg/mylv
```

### 5.4 Verify the new size

```bash
df -h /mnt/lvm
```

The filesystem should now be ~700 MB (500 + 200).

### 5.5 Verify data is intact

```bash
cat /mnt/lvm/testfile.txt
```

**Expected output:**
```
Hello LVM
```

**Verification:** Filesystem grew from 500 MB to ~700 MB, data preserved.

---

## Exercise 06 — Snapshots

**Goal:** Take a point-in-time copy of a volume for backup or testing.

LVM snapshots use Copy-on-Write (COW): when original data is about to change, the old data is copied to the snapshot first. The snapshot only stores differences, so it starts small and grows as the original changes.

### 6.1 Create a snapshot

```bash
sudo lvcreate --yes -s -L 200M -n mysnap /dev/myvg/mylv
```

### 6.2 Verify snapshot exists

```bash
sudo lvs
```

You should see `mysnap` with attribute `swi-a-s--` (snapshot).

### 6.3 Mount the snapshot (read-only)

```bash
sudo mkdir -p /mnt/snap
sudo mount -o ro /dev/myvg/mysnap /mnt/snap
```

### 6.4 Verify snapshot has the same data

```bash
cat /mnt/snap/testfile.txt
```

**Expected output:**
```
Hello LVM
```

### 6.5 Modify the original

```bash
echo "Modified after snapshot" | sudo tee /mnt/lvm/testfile.txt
```

### 6.6 Snapshot still has the old data

```bash
cat /mnt/snap/testfile.txt
```

**Expected output:**
```
Hello LVM
```

The snapshot preserved the data as it was when created.

### 6.7 Clean up snapshot

```bash
sudo umount /mnt/snap
sudo lvremove -f /dev/myvg/mysnap
```

**Verification:** Snapshot preserved original data even after the original was modified.

---

## Exercise 07 — Cleanup

**Goal:** Remove all LVM objects cleanly and understand the removal order.

LVM objects must be removed in reverse order: unmount filesystems → remove LVs → remove VG → remove PVs. Trying to remove a VG with active LVs will fail.

### 7.1 Unmount all filesystems

```bash
sudo umount /mnt/lvm /mnt/xfs /mnt/snap 2>/dev/null
```

### 7.2 Remove all LVs

```bash
sudo lvremove -f myvg
```

### 7.3 Remove the VG

```bash
sudo vgremove myvg
```

### 7.4 Remove PVs

The `-ff` flag forces removal even if the PVs still contain residual metadata. `wipefs -a` erases any remaining filesystem or partition-table signatures, leaving the disks truly clean:

```bash
sudo pvremove -ff /dev/vdb /dev/vdc /dev/vdd
sudo wipefs -a /dev/vdb /dev/vdc /dev/vdd
```

### 7.5 Verify clean state

```bash
sudo pvs
sudo vgs
sudo lvs
```

All should return empty tables.

**Verification:** No LVM objects remain, disks are back to raw state.

---

## Troubleshooting

### "Device or resource busy"
```bash
# Check what's using the LV
sudo lsof /mnt/lvm
# Unmount first
sudo umount /mnt/lvm
```

### "Insufficient free space"
```bash
# Check free space in VG
sudo vgs
# Add another PV
sudo pvcreate -f /dev/vde
sudo vgextend myvg /dev/vde
```

### Can't remove VG
```bash
# Remove all LVs first
sudo lvremove -f myvg
# Then remove VG
sudo vgremove myvg
```

### Packages not installed
```bash
cloud-init status --wait
```
