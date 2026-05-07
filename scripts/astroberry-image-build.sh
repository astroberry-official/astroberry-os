#!/bin/bash
#
# astroberry-image-build.sh
# Prepare vanilla system image for customization
# Invoked by: .github/workflows/astroberry-os-image.yml
#

set -e

# Check input args
if [ $# -lt 1 ]; then
    echo "Output image file missing!"
    echo "Usage ${0} IMAGE_FILE.img"
    exit 1
fi

OUTPUT_IMAGE="$1"

# Check if image exists
if [ ! -f "$OUTPUT_IMAGE" ]; then
    echo "$OUTPUT_IMAGE does not exist!"
    exit 2
fi

# Set working dir
WDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

# Mount partitions
mount "${LOOP_DEV}p2" "$ROOTFS"
mount "${LOOP_DEV}p1" "$ROOTFS/boot/firmware"

# Prepare chroot environment
mount -t proc /proc "$ROOTFS/proc"
mount -t sysfs /sys "$ROOTFS/sys"
mount --rbind /dev "$ROOTFS/dev"
mount --rbind /dev/pts "$ROOTFS/dev/pts"

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
umount "$ROOTFS/boot/firmware"
umount "$ROOTFS"

# Check filesystem before shrinking
e2fsck -fy "${LOOP_DEV}p2"

# Shrink filesystem to minimum size
resize2fs -M "${LOOP_DEV}p2"

# Synchronize filesystem
sync
