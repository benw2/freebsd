#!/bin/sh
swap_size="2G"
zroot_size="8G"

camcontrol devlist

echo "Setting up ZFS drive, with a swap of ${swap_size} and zroot of ${zroot_size}..."

# Prompt for user input, save it in the disk variable
read -p "Enter the disk to partition (e.g., ada0): " disk

gpart destroy       ${disk}
gpart create -s gpt ${disk}

echo "Creating partitions on /dev/${disk}..."

gpart add -a 4k -s 260M -t efi ${disk}
# Create a FAT32 partition
newfs_msdos -F 32 -c 1        /dev/${disk}p1
mount -t msdosfs -o longnames /dev/${disk}p1 /mnt
mkdir -p /mnt/EFI/BOOT
cp /boot/loader.efi /mnt/EFI/BOOT/BOOTX64.efi
umount /mnt

echo "Setting up SWAP and ZFS partitions..."

gpart add -a 1m -s ${swap_size}  -t freebsd-swap -l swap0    ${disk}
gpart add -a 1m -s ${zroot_size} -t freebsd-zfs  -l zroot    ${disk}
gpart add -a 1m                  -t freebsd-zfs  -l zrootenc ${disk}

# Setup ZFS
gpart show ${disk}

sleep 10

