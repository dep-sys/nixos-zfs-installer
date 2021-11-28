#!/usr/bin/env bash
# This DELETES and REFORMATS all data on the given disk

set -euxo pipefail

export DISK=/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_drive-scsi0-0-0-0
export EFI=false

# delete existing partitions
sgdisk -Z $DISK

# part2: boot partition, needed for legacy (BIOS) boot.
sgdisk -a1 -n2:34:2047 -t2:EF02 $DISK

# part3: efi boot
sgdisk -n3:1M:+512M -t3:EF00 $DISK

# part1: zfs
sgdisk -n1:0:0 -t1:BF01 $DISK

# reload partition table
partprobe

zpool create \
	-o ashift=12 \
	-O mountpoint=legacy \
	-O atime=off \
	-O acltype=posixacl \
	-O xattr=sa \
	-O compression=on \
	-O encryption=on \
	-O keyformat=passphrase \
	rpool $DISK-part1

zfs create -p -o mountpoint=legacy rpool/local/root
zfs snapshot rpool/local/root@blank
mount -t zfs rpool/local/root /mnt

mkfs.vfat $DISK-part3
mkdir /mnt/boot
mount $DISK-part3 /mnt/boot

zfs create -p -o mountpoint=legacy rpool/local/nix
mkdir /mnt/nix
mount -t zfs rpool/local/nix /mnt/nix

zfs create -p -o mountpoint=legacy rpool/safe/home
mkdir /mnt/home
mount -t zfs rpool/safe/home /mnt/home

zfs create -p -o mountpoint=legacy rpool/safe/persist
mkdir /mnt/persist
mount -t zfs rpool/safe/persist /mnt/persist

# TODO copy flake
nixos-install \
    --no-channel-copy \
    --root /mnt \
    --no-root-passwd \
    --flake .#base
