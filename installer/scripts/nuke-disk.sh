#!/usr/bin/env bash
# This DELETES and REFORMATS all data on the given disk

set -euxo pipefail

export DISK="$1"

# delete existing partitions
sgdisk -Z "$DISK"

# part2: boot partition, needed for legacy (BIOS) boot.
sgdisk -a1 -n2:34:2047 -t2:EF02 "$DISK"

# part3: efi boot
sgdisk -a1 -n3:1M:+512M -t3:EF00 "$DISK"

# part1: zfs
sgdisk -a1 -n1:0:0 -t1:BF01 "$DISK"

# reload partition table
partprobe

# create tempfile for password
KEYFILE=$(mktemp)
read-disk-key > "$KEYFILE"

zpool create \
	-o ashift=12 \
	-o altroot="/mnt" \
	-O mountpoint=legacy \
	-O atime=off \
	-O acltype=posixacl \
	-O xattr=sa \
	-O compression=on \
	-O encryption=on \
	-O keyformat=passphrase \
	-O keylocation="file://$KEYFILE" \
	rpool "$DISK-part1"

shred -u "$KEYFILE"
zfs set keylocation="prompt" rpool

zfs create -p -o mountpoint=legacy rpool/local/root
zfs snapshot rpool/local/root@blank
mount -t zfs rpool/local/root /mnt

mkfs.vfat "$DISK-part3"
mkdir /mnt/boot
mount "$DISK-part3" /mnt/boot

zfs create -p -o mountpoint=legacy rpool/local/nix
mkdir /mnt/nix
mount -t zfs rpool/local/nix /mnt/nix

zfs create -p -o mountpoint=legacy rpool/safe/home
mkdir /mnt/home
mount -t zfs rpool/safe/home /mnt/home

zfs create -p -o mountpoint=legacy rpool/safe/persist
mkdir /mnt/persist
mount -t zfs rpool/safe/persist /mnt/persist

