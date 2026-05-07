#!/bin/bash
set -e

# 1. Hardware Detection
MEDIA_PATH="/cdrom/installer"
IMAGE_FILE=$(ls $MEDIA_PATH/*.tar.zst | head -n 1)

# Finding the largest non-removable, writable disk
TARGET_DRIVE=$(lsblk -bndo NAME,TYPE,RO,RM,SIZE | \
    awk '$2=="disk" && $3=="0" && $4=="0" {print $1, $5}' | \
    sort -rnk2 | head -n1 | awk '{print "/dev/"$1}')

# Safety check: Exit if no drive found
if [ -z "$TARGET_DRIVE" ]; then
    echo "ERROR: No suitable target drive found!"
    lsblk
    exit 1
fi

# Gather Summary Info
DISK_SIZE=$(lsblk -dn -o SIZE "$TARGET_DRIVE")
DISK_MODEL=$(cat "/sys/block/${TARGET_DRIVE#/dev/}/device/model" 2>/dev/null || echo "Virtual Disk")

# --- ADDED: Summary & Confirmation ---
clear
echo "========================================================"
echo "          ASTROBERRY OS INSTALLATION SUMMARY            "
echo "========================================================"
printf "%-20s %s\n" "Target Drive:"   "$TARGET_DRIVE"
printf "%-20s %s\n" "Model:"          "$DISK_MODEL"
printf "%-20s %s\n" "Capacity:"       "$DISK_SIZE"
printf "%-20s %s\n" "Source Image:"   "${IMAGE_FILE##*/}"
echo "--------------------------------------------------------"
echo " WARNING: ALL DATA ON $TARGET_DRIVE WILL BE DESTROYED!"
echo "========================================================"
echo ""
read -p " Type 'yes' to proceed with installation: " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Installation aborted by user."
    exit 1
fi
# -------------------------------------

[[ $TARGET_DRIVE == *nvme* ]] && PART_EXT="p" || PART_EXT=""
EFI_PART="${TARGET_DRIVE}${PART_EXT}1"
ROOT_PART="${TARGET_DRIVE}${PART_EXT}2"

echo ""

# 2. Partition & Format
printf "Partitioning $TARGET_DRIVE: creating label"
parted --script "$TARGET_DRIVE" mklabel gpt
printf ", creating EFI partition"
parted --script "$TARGET_DRIVE" mkpart primary fat32 1MiB 513MiB
parted --script "$TARGET_DRIVE" set 1 esp on
printf ", creating root partition\n"
parted --script "$TARGET_DRIVE" mkpart primary ext4 513MiB 100%

udevadm settle
printf "Formatting partitions: EFI"
mkfs.vfat -F32 -n EFI "$EFI_PART" > /dev/null 2>&1
printf ", Root\n"
mkfs.ext4 -F -L rootfs "$ROOT_PART" > /dev/null 2>&1

# 3. Extraction
mkdir -p /mnt/target
mount "$ROOT_PART" /mnt/target
mkdir -p /mnt/target/boot/efi
mount "$EFI_PART" /mnt/target/boot/efi

printf "Extracting System Image...\n"
pv "$IMAGE_FILE" | tar --zstd -xpf - -C /mnt/target

# 4. Generate the fstab
echo "Creating fstab file..."
ROOT_UUID=$(lsblk -dn -o UUID "$ROOT_PART")
EFI_UUID=$(lsblk -dn -o UUID "$EFI_PART")
cat <<EOF > "/mnt/target/etc/fstab"
UUID=$ROOT_UUID / ext4 errors=remount-ro 0 1
UUID=$EFI_UUID /boot/efi vfat umask=0077 0 1
EOF

# 5. The Chroot Trigger
printf "Entering Chroot to trigger the bootloader installation...\n"
mount --bind /dev /mnt/target/dev
mount --bind /proc /mnt/target/proc
mount --bind /sys /mnt/target/sys
mount --bind /sys/firmware/efi/efivars /mnt/target/sys/firmware/efi/efivars
chroot /mnt/target /bin/bash -c "
    # Update the initramfs to ensure it matches the new UUIDs
    update-initramfs -u
    
    # Install GRUB using the signed Ubuntu binaries
    grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=astroberry --recheck
    
    # Generate the grub.cfg
    echo 'GRUB_CMDLINE_LINUX_DEFAULT=\"net.ifnames=0 biosdevname=0\"' > /etc/default/grub
    update-grub
"

# 6. Cleanup
printf "Cleaning up...\n"
umount /mnt/target/dev /mnt/target/proc /mnt/target/sys/firmware/efi/efivars /mnt/target/sys
umount /mnt/target/boot/efi
umount /mnt/target
sync; sync

printf "Deployment complete. System is ready.\n"
printf "Waiting 10 seconds to reboot...\n"
sleep 10
echo 1 > /proc/sys/kernel/sysrq
echo b > /proc/sysrq-trigger