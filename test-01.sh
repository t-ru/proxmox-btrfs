#!/bin/sh

# Set Variables
PARTITION_BTRFS_UUID=$(cat /target/etc/fstab | grep " /  " | grep "^UUID=" | cut -d "=" -f 2 | cut -d " " -f 1)
PARTITION_BTRFS_DEVICE=$(blkid -o device -U $PARTITION_BTRFS_UUID)
PARTITION_EFI_UUID=$(cat /target/etc/fstab | grep " /boot/efi " | grep "^UUID=" | cut -d "=" -f 2 | cut -d " " -f 1)
PARTITION_EFI_DEVICE=$(blkid -o device -U $PARTITION_EFI_UUID)
echo $PARTITION_BTRFS_UUID
echo $PARTITION_BTRFS_DEVICE
echo $PARTITION_EFI_UUID
echo $PARTITION_EFI_DEVICE



# Unmount
umount /target/boot/efi
umount /target



#Mount BTRFS partition
mount $PARTITION_BTRFS_DEVICE /mnt



# Rename subvolume "@rootfs"
mv /mnt/@rootfs /mnt/@



# Create subvolumes
btrfs subvolume create /mnt/@/.snapshots
mkdir /mnt/@/.snapshots/1
btrfs subvolume create /mnt/@/.snapshots/1/snapshot
mkdir /mnt/@/var
btrfs subvolume create /mnt/@/var/log



# Migrate data from subvolume "@" to "@/.snapshots/1/snapshot"
cp -aR /mnt/@/media /mnt/@/.snapshots/1/snapshot
cp -aR /mnt/@/etc /mnt/@/.snapshots/1/snapshot
cp -aR /mnt/@/boot /mnt/@/.snapshots/1/snapshot



# Remove migrated data from subvolume "@"
rm -rf /mnt/@/media
rm -rf /mnt/@/etc
rm -rf /mnt/@/boot



# Create mountpoints on subvolume "@/.snapshots/1/snapshot"
mkdir -p /mnt/@/.snapshots/1/snapshot/.snapshots
mkdir -p /mnt/@/.snapshots/1/snapshot/var/log


# Create new fstab
cat << EOF > /mnt/@/.snapshots/1/snapshot/etc/fstab
# /etc/fstab: static file system information.
#
# Use 'blkid' to print the universally unique identifier for a
# device; this may be used with UUID= as a more robust way to name devices
# that works even if disks are added and removed. See fstab(5).
#
# systemd generates mount units based on this file, see systemd.mount(5).
# Please run 'systemctl daemon-reload' after making changes here.
#
# <file system> <mount point>   <type>  <options>       <dump>  <pass>

# EFI system partition
UUID=$PARTITION_EFI_UUID  /boot/efi  vfat  umask=0077  0  1

# BTRFS subvolumes
UUID=$PARTITION_BTRFS_UUID  /                         btrfs  defaults                           0  0
UUID=$PARTITION_BTRFS_UUID  /.snapshots               btrfs  subvol=/@/.snapshots               0  0
UUID=$PARTITION_BTRFS_UUID  /var/log                  btrfs  subvol=/@/var/log                  0  0
EOF


# Make subvolume "@/.snapshots/1/snapshot" to default subvolume
btrfs subvolume set-default $(btrfs subvolume list /mnt | grep @/.snapshots/1/snapshot | cut -d " " -f 2) /mnt



# Unmount
umount /mnt



# Mount
mount $PARTITION_BTRFS_DEVICE -o defaults /target
mount $PARTITION_BTRFS_DEVICE -o subvol=/@/.snapshots /target/.snapshots
mount $PARTITION_BTRFS_DEVICE -o subvol=/@/var/log /target/var/log
mount $PARTITION_EFI_DEVICE -o umask=0077 /target/boot/efi



# Fix permissionson /target/.snapshots
chmod 750 /target/.snapshots
umount /target/.snapshots
mount $PARTITION_BTRFS_DEVICE -o subvol=/@/.snapshots /target/.snapshots
