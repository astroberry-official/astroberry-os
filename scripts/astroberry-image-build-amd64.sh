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
ROOTFS="/mnt/rootfs"
mkdir -p "$ROOTFS"

# Clean everything on exit
cleanup() {
    for dir in proc sys dev/pts dev; do
        if mountpoint -q "$ROOTFS/$dir"; then
            umount -l "$ROOTFS/$dir"
        fi
    done

    if mountpoint -q "$ROOTFS/boot/firmware"; then
        umount "$ROOTFS/boot/firmware"
    fi

    if mountpoint -q "$ROOTFS"; then
        umount "$ROOTFS"
    fi

    if [ -n "$LOOP_DEV" ]; then
        losetup -d "$LOOP_DEV"
    fi

    rmdir "$ROOTFS"
}
trap cleanup EXIT

# Create the initial debootstrap for the astroberry OS image
debootstrap --arch amd64 trixie "$ROOTFS" http://deb.debian.org/debian/

# Prepare chroot environment
mount -t proc /proc "$ROOTFS/proc"
mount -t sysfs /sys "$ROOTFS/sys"
mount --rbind /dev "$ROOTFS/dev"
mount --rbind /dev/pts "$ROOTFS/dev/pts"

sed -i 's/main$/main contrib non-free-firmware non-free/' "$ROOTFS/etc/apt/sources.list"
chroot "$ROOTFS" apt-get update
chroot "$ROOTFS" apt-get install -y --no-install-recommends linux-image-generic firmware-linux-nonfree \
  shim-signed grub-efi-amd64-signed \
  intel-microcode va-driver-all haveged zstd cloud-init sudo console-setup
chroot "$ROOTFS" apt-get install -y curl gpg
chroot "$ROOTFS" apt-get clean

# Add Astroberry OS certificate
curl -fsSL https://astroberry.io/debian/astroberry.asc | gpg --dearmor -o "$ROOTFS/etc/apt/keyrings/astroberry.gpg"

# Add Astroberry OS repository
cat <<EOF > "$ROOTFS/etc/apt/sources.list.d/astroberry.sources"
Types: deb
URIs: https://astroberry.io/debian/
Suites: trixie
Components: main
Signed-By: /etc/apt/keyrings/astroberry.gpg
EOF

# Give priority to Astroberry OS repository
cat <<EOF > "$ROOTFS/etc/apt/preferences.d/astroberry-pin"
Package: *
Pin: origin astroberry.io
Pin-Priority: 900
EOF

# Add post-installation clean up script
cat <<EOF > "$ROOTFS/tmp/astroberry-os-cleanup.sh"
#!/bin/bash

# Clean AstroDMx leftovers
rm -rf /install.sh # AstroDMx leftover
echo "NoDisplay=true" >> /usr/share/desktop-directories/astrodmx.directory # remove astrodmx from top level menu

# Clean packages
apt-get remove -y --purge modemmanager
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
chmod 755 "$ROOTFS/tmp/astroberry-os-cleanup.sh"

# Install Astroberry OS meta package
chroot "$ROOTFS" /bin/bash -c "export DEBIAN_FRONTEND=noninteractive && apt-get update && apt-get install -y astroberry-os-desktop && /tmp/astroberry-os-cleanup.sh"

# Unmount filesystems
for dir in proc sys dev/pts dev; do
    umount -l "$ROOTFS/$dir"
done

# Synchronize filesystem
sync

# Create archive
OUTPUT_ARCHIVE="${ISOFILE%.iso}.tar.zst"
tar --zstd -cvf $OUTPUT_ARCHIVE -C $ROOTFS .

# Clean ROOTFS
rm -rf $ROOTFS/*

############## ISO/Installer creation section ################
ISOROOTFS="isorootfs"
if [ -e "$ISOROOTFS" ]; then rm -rf "$ISOROOTFS"; fi
mkdir "$ISOROOTFS"

# Create the installer debootstrap image
debootstrap --variant=minbase --include=e2fsprogs,fdisk,gdisk,parted,tar,gzip,udev,kmod,dosfstools,pv,zstd \
  trixie "$ISOROOTFS" http://deb.debian.org/debian/

# Install the kernel
chroot "$ISOROOTFS" apt-get update
chroot "$ISOROOTFS" apt-get install -y --no-install-recommends linux-image-generic
chroot "$ISOROOTFS" apt-get clean

# Copying the init script into the chroot
cp -v $WDIR/iso-installer-amd64/init.sh "$ISOROOTFS/init"
chmod +x "$ISOROOTFS/init"

# Copying the installer scripts
mkdir -p iso/installer
cp -v $WDIR/iso-installer-amd64/deploy.sh iso/installer
chmod +x iso/installer/deploy.sh
cp -v $OUTPUT_ARCHIVE iso/installer/

# Creating and populating the grub ISO structure
mkdir -p iso/boot/grub
KERNEL=$(ls "$ISOROOTFS/boot/vmlinuz-*")
cp -v $KERNEL iso/boot/vmlinuz
(cd "$ISOROOTFS" && find . | cpio -H newc -o | gzip > ../iso/boot/initrd.img)
cp -v $WDIR/iso-installer-amd64/grub.cfg iso/boot/grub

# Secure boot support
mkdir -p "iso/EFI/BOOT"
cp iso/boot/grub/grub.cfg "iso/EFI/BOOT/grub.cfg"
cp iso/boot/grub/grub.cfg "iso/grub.cfg"
cp /usr/lib/shim/shimx64.efi.signed "iso/EFI/BOOT/BOOTX64.EFI"
cp /usr/lib/grub/x86_64-efi-signed/grubx64.efi.signed "iso/EFI/BOOT/grubx64.efi"
cp /usr/lib/shim/mmx64.efi "iso/EFI/BOOT/"
if [ -e "efiboot.img" ]; then rm -rf efiboot.img; fi
truncate -s 8M efiboot.img
mkfs.vfat -F12 -n "EFI_BOOT" efiboot.img
mmd -i efiboot.img ::/EFI
mmd -i efiboot.img ::/EFI/BOOT
mcopy -i efiboot.img iso/EFI/BOOT/* ::/EFI/BOOT/
mcopy -i efiboot.img iso/boot/grub/grub.cfg ::/grub.cfg

# Actual ISO file creation
xorriso -as mkisofs -r -V astroberrycd -o $ISOFILE \
  -J -joliet-long -no-emul-boot -e efiboot.img \
  -isohybrid-gpt-basdat -isohybrid-apm-hfsplus \
  iso efiboot.img

# Showing the end ISO file
ls -al $ISOFILE

# Cleanup
rm -rf $ISOROOTFS iso efiboot.img $OUTPUT_ARCHIVE