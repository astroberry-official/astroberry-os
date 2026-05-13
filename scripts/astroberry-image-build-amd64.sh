#!/bin/bash
#
# astroberry-image-build.sh
# Prepare vanilla system image for customization (amd64 variant)
# Invoked by: .github/workflows/astroberry-os-image-amd64.yml

set -e

# Check input args
if [ $# -lt 1 ]; then
    echo "Output ISO file missing!"
    echo "Usage ${0} ISOFILE.iso"
    exit 1
fi

ISOFILE="$1"

# Set working dir
WDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Create root filesystem mount point
ROOTFS="rootfs"
if [ ! -e $ROOTFS ]; then mkdir -p $ROOTFS; fi

# Clean everything on exit
cleanup() {
    for dir in proc sys dev/pts dev; do
        if mountpoint -q $ROOTFS/$dir; then
            umount -l $ROOTFS/$dir
        fi
    done

    if mountpoint -q $ROOTFS/boot/firmware; then
        umount $ROOTFS/boot/firmware
    fi

    if mountpoint -q $ROOTFS; then
        umount $ROOTFS
    fi

    if [ -n "$LOOP_DEV" ]; then
        losetup -d "$LOOP_DEV"
    fi

    rm -rf $ROOTFS $ISOROOTFS iso efiboot.img $OUTPUT_ARCHIVE
}
trap cleanup EXIT

# Create the initial debootstrap for the astroberry OS image
debootstrap --arch amd64 trixie $ROOTFS http://deb.debian.org/debian/

# Prepare chroot environment
mount -t proc /proc $ROOTFS/proc
mount -t sysfs /sys $ROOTFS/sys
mount --rbind /dev $ROOTFS/dev
mount --rbind /dev/pts $ROOTFS/dev/pts

sed -i 's/main$/main contrib non-free-firmware non-free/' $ROOTFS/etc/apt/sources.list
chroot $ROOTFS apt-get update
chroot $ROOTFS apt-get install -y --no-install-recommends linux-image-generic firmware-linux-nonfree \
  shim-signed grub-efi-amd64-signed grub-efi-amd64 grub-pc-bin \
  intel-microcode va-driver-all haveged zstd cloud-init sudo console-setup
chroot $ROOTFS apt-get install -y curl gpg

# Add support live booting and new installer
chroot $ROOTFS apt-get install -y squashfs-tools live-boot live-config live-config-systemd zenity

# Add Astroberry OS certificate
curl -fsSL https://astroberry.io/debian/astroberry.asc | gpg --dearmor -o $ROOTFS/etc/apt/keyrings/astroberry.gpg

# Add Astroberry OS repository
cat <<EOF > $ROOTFS/etc/apt/sources.list.d/astroberry.sources
Types: deb
URIs: https://astroberry.io/debian/
Suites: trixie
Components: main
Signed-By: /etc/apt/keyrings/astroberry.gpg
EOF

# Give priority to Astroberry OS repository
cat <<EOF > $ROOTFS/etc/apt/preferences.d/astroberry-pin
Package: *
Pin: origin astroberry.io
Pin-Priority: 900
EOF

# Add post-installation clean up script
cat <<EOF > $ROOTFS/tmp/astroberry-os-cleanup.sh
#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

# Remove packages we don't need
apt-get remove -y --purge modemmanager light-locker
apt-get autoremove -y

# Clean apt cache
apt-get clean
rm -rf /var/cache/apt/archives/*.deb
rm -rf /var/cache/apt/archives/partial/*
rm -rf /var/lib/apt/lists/*

# Clean logs
find /var/log -type f -name "*.log" -delete
find /var/log -type f -name "*.log.*" -delete
find /var/log -type f -name "*.gz" -delete
truncate -s 0 /var/log/lastlog
truncate -s 0 /var/log/wtmp
truncate -s 0 /var/log/btmp

# Clean tmp
rm -rf /tmp/*
rm -rf /var/tmp/*

# Clean caches
rm -rf /home/*/.cache/*
rm -rf /root/.cache/*

# Clean bash history
rm -f /home/*/.bash_history
rm -f /root/.bash_history

# Truncate journal
journalctl --vacuum-time=1s
rm -rf /var/log/journal/*

# Remove self
rm -rf /tmp/astroberry-os-cleanup.sh
EOF
chmod +x $ROOTFS/tmp/astroberry-os-cleanup.sh

# Install Astroberry OS meta package
chroot $ROOTFS /bin/bash -c \
  "export DEBIAN_FRONTEND=noninteractive && apt-get update && apt-get -o Dpkg::Options::=\"--force-overwrite\" install -yqq astroberry-os-desktop && /tmp/astroberry-os-cleanup.sh"

# Copy the installer and icon files to the image
cp $WDIR/astroberry-installer.sh $ROOTFS/opt/
cp $WDIR/astroberry-installer.desktop $ROOTFS/usr/share/applications/

# Copy the installer and icon files to the image
cp $WDIR/astroberry-installer.sh $ROOTFS/opt/
cp $WDIR/astroberry-installer.desktop $ROOTFS/usr/share/applications/

# Change the default grub configuration for old nic names
sed -i '/GRUB_CMDLINE_LINUX_DEFAULT/c\GRUB_CMDLINE_LINUX_DEFAULT="quiet net.ifnames=0 biosdevname=0"' $ROOTFS/etc/default/grub

# Synchronize filesystem
sync

# Unmount filesystems
for dir in proc sys dev/pts dev; do
    umount -l $ROOTFS/$dir
done

# Create the iso structure
[ -e iso ] && rm -rf iso
mkdir -p iso/EFI/BOOT
mkdir -p iso/boot/grub/i386-pc
mkdir -p iso/live

# Create the squashfs image with xz compression
mksquashfs $ROOTFS iso/live/filesystem.squashfs -comp xz

# Copy the kernel and initrd from the chroot to the iso
KERNEL=$(ls $ROOTFS/boot/vmlinuz-*)
cp -v $KERNEL iso/live/vmlinuz
INITRD=$(ls $ROOTFS/boot/initrd.img-*)
cp -v $INITRD iso/live/initrd

# Copy the shim and grub bootloader to the iso
cp $ROOTFS/usr/lib/shim/shimx64.efi.signed iso/EFI/BOOT/BOOTX64.EFI
cp $ROOTFS/usr/lib/grub/x86_64-efi-signed/grubx64.efi.signed iso/EFI/BOOT/grubx64.efi

# Create the grub configuration for the iso
cat << EOF > iso/EFI/BOOT/grub.cfg
set default="0"
set timeout=5

insmod part_gpt
insmod part_msdos
insmod all_video

menuentry "Astroberry Live" {
    search --set=root --file /live/filesystem.squashfs
    linux /live/vmlinuz boot=live components quiet splash noeject noautologin net.ifnames=0 biosdevname=0
    initrd /live/initrd
}
EOF

# Create the EFI boot image
truncate -s 10M efiboot.img
mkfs.vfat efiboot.img
mmd -i efiboot.img ::/EFI ::/EFI/BOOT
mcopy -i efiboot.img iso/EFI/BOOT/BOOTX64.EFI ::/EFI/BOOT/
mcopy -i efiboot.img iso/EFI/BOOT/grubx64.efi ::/EFI/BOOT/

# Create the el-torito image for legacy BIOS booting
grub-mkimage -O i386-pc-eltorito \
    -o iso/boot/grub/i386-pc/eltorito.img \
    -p /boot/grub \
    biosdisk iso9660 search test ls normal cat echo halt reboot

# Create the final ISO image
xorriso -as mkisofs \
    -iso-level 3 -rock -joliet \
    -volid "ASTROBERRY" \
    -partition_offset 16 \
    -append_partition 2 0xef efiboot.img \
    -appended_part_as_gpt \
    -c boot.catalog \
    -b boot/grub/i386-pc/eltorito.img \
      -no-emul-boot -boot-load-size 4 -boot-info-table \
    -eltorito-alt-boot \
    -e '--interval:appended_partition_2:all::' \
      -no-emul-boot \
    -o $ISOFILE \
    iso/

# Cleanup
rm -rf iso efiboot.img

# Show the generated ISO file
ls -al $ISOFILE

