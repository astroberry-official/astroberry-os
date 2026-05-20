#!/bin/bash
#
# astroberry-image-build.sh
# Generate Astroberry OS image for a given architecture and distribution
# Invoked by: .github/workflows/astroberry-os-release.yml
#

set -e

#############################################################################
#      ASTROBERRY OS PROCEDURE
#############################################################################

install-astroberryos() {

    # Add Astroberry OS certificate
    curl -fsSL https://astroberry.io/debian/astroberry.asc | gpg --dearmor -o $ROOTFS/etc/apt/keyrings/astroberry.gpg

    # Add Astroberry OS repository
    cat <<EOF > $ROOTFS/etc/apt/sources.list.d/astroberry.sources
Types: deb
URIs: https://astroberry.io/debian/
Suites: trixie
Architectures: arm64 amd64
Components: main restricted
Signed-By: /etc/apt/keyrings/astroberry.gpg
EOF

    # Give priority to Astroberry OS repository
    cat <<EOF > $ROOTFS/etc/apt/preferences.d/astroberry-pin
Package: *
Pin: origin astroberry.io
Pin-Priority: 900
EOF

    # Set wireless regulatory domain
    if [ -e $ROOTFS/boot/firmware/cmdline.txt ] && [ -z "$(grep cfg80211.ieee80211_regdom $ROOTFS/boot/firmware/cmdline.txt)" ]; then
        sed -i -e "s/\s*cfg80211.ieee80211_regdom=\S*//" -e "s/\(.*\)/\1 cfg80211.ieee80211_regdom=GB/" $ROOTFS/boot/firmware/cmdline.txt
    fi

    # Add post-installation clean up script
    cat <<EOF > $ROOTFS/tmp/astroberry-os-cleanup.sh
#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

######################   Custom Fixes ###############################

# Clean AstroDMx installation files
if [ -e /install.sh ]; then
    rm -rf /install.sh
fi

# Remove AstroDMx from top level menu
[ -e /usr/share/desktop-directories/astrodmx.directory ] && rm -rf /usr/share/desktop-directories/astrodmx.directory

# Fix AstroDMx desktop file
[ -e /usr/share/applications/astrodmx_capture.desktop ] && sed -i "s/Categories=.*/Categories=Education;Science;Astronomy;/g" /usr/share/applications/astrodmx_capture.desktop

# Fix Firecapture desktop file
if [ ! -e /usr/share/applications/firecapture.desktop ] && [ -e /usr/share/applications/FireCapture\ v2.7.desktop ]; then
    mv /usr/share/applications/FireCapture\ v2.7.desktop /usr/share/applications/firecapture.desktop
    sed -i "/Terminal=true/d" /usr/share/applications/firecapture.desktop
    sed -i "s/Categories=.*/Categories=Education;Science;Astronomy;/g" /usr/share/applications/firecapture.desktop
fi

######################################################################

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

    # Make cleanup script executable
    chmod +x $ROOTFS/tmp/astroberry-os-cleanup.sh

    # Install Astroberry OS meta package
    chroot $ROOTFS apt-get update
    chroot $ROOTFS apt-get install -y astroberry-os-desktop
    chroot $ROOTFS /tmp/astroberry-os-cleanup.sh

}

#############################################################################
#      ARM64 PROCEDURE
#############################################################################
build-arm64() {
    echo
    echo "Building ARM64 image"
    echo

    # Get Raspberry Pi OS image
    IMAGE_URL="https://downloads.raspberrypi.org/raspios_lite_arm64/images/raspios_lite_arm64-2025-12-04"
    IMAGE_FILE="2025-12-04-raspios-trixie-arm64-lite.img"
    wget -c "$IMAGE_URL/$IMAGE_FILE.xz"
    wget -c "$IMAGE_URL/$IMAGE_FILE.xz.sha256"

    # Verify image SHA256 sum
    if [ "OK" != "$(sha256sum -c $IMAGE_FILE.xz.sha256 | awk -F: '{print $2}' | xargs)" ]; then
        echo "Raspberry Pi OS image SHA256 sum verification failed!"
        rm -f "$IMAGE_FILE.xz"
        rm -f "$IMAGE_FILE.xz.sha256"
        return 1
    fi

    # Decompress image
    unxz "$IMAGE_FILE.xz" && mv "$IMAGE_FILE" "$OUTPUT_IMAGE"

    # Verify output image
    if [ ! -e "$OUTPUT_IMAGE" ]; then
        echo "Failed to decompress Raspberry Pi OS image!"
        rm -f "$IMAGE_FILE.xz"
        rm -f "$IMAGE_FILE.xz.sha256"
        return 1
    fi

    # Grow image +7GB
    truncate -s +7G "$OUTPUT_IMAGE"
    sync

    # Set up loop device
    LOOP_DEV=$(losetup -fP --show "$OUTPUT_IMAGE")

    # Wait for partition
    while [ ! -e "${LOOP_DEV}p2" ]; do
        sleep 3
    done

    # Check and grow root filesystem to maximum size
    e2fsck -fy "${LOOP_DEV}p2"
    parted "${LOOP_DEV}" resizepart 2 100%
    resize2fs "${LOOP_DEV}p2"
    sync

    # Mount partitions
    mount "${LOOP_DEV}p2" "$ROOTFS"
    mount "${LOOP_DEV}p1" "$ROOTFS/boot/firmware"

    # Prepare chroot environment
    mount -t proc /proc "$ROOTFS/proc"
    mount -t sysfs /sys "$ROOTFS/sys"
    mount --rbind /dev "$ROOTFS/dev"
    mount --rbind /dev/pts "$ROOTFS/dev/pts"

    # Install Astroberry OS
    install-astroberryos

    # Synchronize filesystem
    sync

    # Unmount filesystems
    for dir in proc sys dev/pts dev; do
        mountpoint -q $ROOTFS/$dir && umount -l $ROOTFS/$dir
    done
    mountpoint -q $ROOTFS/boot/firmware && umount $ROOTFS/boot/firmware
    mountpoint -q $ROOTFS && umount $ROOTFS

    # Check filesystem before shrinking
    e2fsck -fy "${LOOP_DEV}p2"

    # Shrink filesystem to minimum size
    resize2fs -M "${LOOP_DEV}p2"
    sync

    # Detach loop device
    losetup -d "$LOOP_DEV"

    # Shrink image
    [ -e "$OUTPUT_IMAGE.xz" ] && rm -rf "$OUTPUT_IMAGE.xz"
    pishrink.sh -asZv "$OUTPUT_IMAGE"

    # Generate SHA256 checksum for the output image
    sha256sum "$OUTPUT_IMAGE.xz" > "$OUTPUT_IMAGE.xz.sha256"

    # Display SHA256 checksum
    cat "$OUTPUT_IMAGE.xz.sha256"

    # Verify the output image
    sha256sum -c "$OUTPUT_IMAGE.xz.sha256"
}

#############################################################################
#      AMD64 PROCEDURE
#############################################################################
build-amd64() {
    echo
    echo "Building AMD64 image"
    echo

    # Create the initial debootstrap for the astroberry OS image
    debootstrap --arch amd64 trixie $ROOTFS http://deb.debian.org/debian/

    # Check debootstrap result
    [ $? -ne 0 ] && return 1

    # Prepare chroot environment
    mount -t proc /proc $ROOTFS/proc
    mount -t sysfs /sys $ROOTFS/sys
    mount --rbind /dev $ROOTFS/dev
    mount --rbind /dev/pts $ROOTFS/dev/pts

    # Add Debian repositories and boot components
    sed -i 's/main$/main contrib non-free-firmware non-free/' $ROOTFS/etc/apt/sources.list
    chroot $ROOTFS apt-get update
    chroot $ROOTFS apt-get install -y --no-install-recommends linux-image-generic firmware-linux-nonfree \
    shim-signed grub-efi-amd64-signed grub-efi-amd64 grub-pc-bin \
    intel-microcode va-driver-all haveged zstd cloud-init sudo console-setup \
    live-boot live-config live-config-systemd rsync zenity

    # Install Astroberry OS
    install-astroberryos

    # Change the default grub configuration for old nic names
    sed -i '/GRUB_CMDLINE_LINUX_DEFAULT/c\GRUB_CMDLINE_LINUX_DEFAULT="quiet net.ifnames=0 biosdevname=0"' $ROOTFS/etc/default/grub

    # Copy the installer and icon files to the image
    cp $WDIR/iso-installer-amd64/astroberry-installer.sh $ROOTFS/usr/bin/
    cp $WDIR/iso-installer-amd64/astroberry-installer.desktop $ROOTFS/usr/share/applications/

    # Replace dock launcher: RaspberryPi Control Centre -> Astroberry OS Installer
    sed -i 's/rpcc.desktop/astroberry-installer.desktop/g' $ROOTFS/etc/xdg/xfce4/panel/default.xml

    # Synchronize filesystem
    sync

    # Unmount filesystems
    for dir in proc sys dev/pts dev; do
        mountpoint -q $ROOTFS/$dir && umount -l $ROOTFS/$dir
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

menuentry "Astroberry OS Live (64-bit)" {
    search --set=root --file /live/filesystem.squashfs
    linux /live/vmlinuz boot=live components quiet noeject username=astroberry net.ifnames=0 biosdevname=0
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
        -o $OUTPUT_IMAGE \
        iso/

    # Generate SHA256 checksum for the output image
    sha256sum $OUTPUT_IMAGE > $OUTPUT_IMAGE.sha256

    # Display SHA256 checksum
    cat $OUTPUT_IMAGE.sha256

    # Verify the output image
    sha256sum -c $OUTPUT_IMAGE.sha256

    # Cleanup
    rm -rf iso efiboot.img
}

#############################################################################
#      CLEANUP PROCEDURE
#############################################################################
cleanup() {
    # Unmount filesystems
    for dir in proc sys dev/pts dev; do
        mountpoint -q $ROOTFS/$dir && umount -l $ROOTFS/$dir
    done
    mountpoint -q $ROOTFS/boot/firmware && umount $ROOTFS/boot/firmware
    mountpoint -q $ROOTFS && umount $ROOTFS
    [ -d $ROOTFS ] && rm -rf $ROOTFS
}
trap cleanup EXIT

#############################################################################
#      MAIN PROCEDURE
#############################################################################

# Check input args
[ $# -ne 3 ] && exit 1

VERSION=$1 # e.g. 3.2
DISTRO=$2 # e.g. debian-trixie
ARCH=$3 # e.g. arm64 or amd64

# Set file type based on architecture
if [ "${ARCH}" == "arm64" ]; then
    FILETYPE="img"
elif [ "${ARCH}" == "amd64" ]; then
    FILETYPE="iso"
else
    echo "Unsupported architecture: $ARCH"
    exit 1
fi

# Set output image name
OUTPUT_IMAGE="astroberryos_${VERSION}_${DISTRO}-${ARCH}.${FILETYPE}"

# Set working dir
WDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Create root filesystem mount point
ROOTFS="rootfs"
[ ! -d $ROOTFS ] && mkdir -p $ROOTFS

# Build image based on architecture
if [ "${ARCH}" == "arm64" ]; then
    build-arm64
elif [ "${ARCH}" == "amd64" ]; then
    build-amd64
fi
