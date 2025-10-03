#!/bin/sh
swap_size="2G"
zroot_size="10G"

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

# Mount a tmpfs to /mnt
mount -t tmpfs tmpfs /mnt

echo "Creating ZFS pool and datasets on ${disk}p4..."

zpool create -o ashift=12 -o altroot=/mnt zroot ${disk}p4

zfs set compress=on                                            zroot

zfs create -o mountpoint=none                                  zroot/ROOT
zfs create -o mountpoint=/                                     zroot/ROOT/default
zfs create -o mountpoint=/home                                 zroot/home
zfs create -o mountpoint=/tmp -o exec=on -o setuid=off         zroot/tmp
zfs create -o mountpoint=/usr -o canmount=off                  zroot/usr
zfs create -o setuid=off                                       zroot/usr/ports
zfs create                                                     zroot/usr/src
zfs create -o mountpoint=/var -o canmount=off                  zroot/var
zfs create -o exec=off -o setuid=off                           zroot/var/audit
zfs create -o exec=off -o setuid=off                           zroot/var/crash
zfs create -o exec=off -o setuid=off                           zroot/var/log
zfs create -o atime=on                                         zroot/var/mail
zfs create -o setuid=off                                       zroot/var/tmp

zfs set mountpoint=/zroot zroot

chmod 1777 /mnt/tmp/

mkdir -p /mnt/var/tmp
chmod 1777 /mnt/var/tmp

zpool set bootfs=zroot/ROOT/default zroot

mkdir -p /mnt/boot/zfs

zpool set cachefile=/mnt/boot/zfs/zpool.cache  zroot
zfs   set canmount=noauto                      zroot/ROOT/default

 cat << EOF > /tmp/bsdinstall_etc/fstab
 # Device                       Mountpoint              FStype  Options         Dump    Pass#
 /dev/gpt/swap0                 none                    swap    sw              0       0
 EOF

