#!/bin/bash
#
# astroberry-installer.sh
# Install Astroberry OS to a disk
# Invoke from the live ISO by running:
#     sudo /usr/bin/astroberry-installer.sh

set -ex

TITLE="Astroberry OS Installer"

# 1. Hardware (disk) Selection
DRIVES=$(lsblk -dnpo NAME,TYPE,RO,RM,SIZE,MODEL | awk '$2=="disk" && $3=="0" && $4=="0" {print $1"|"$5"|"$6"-"$7}' | awk -F\| '{ORS=" "; print $1, $3, $2}; ORS="\n"')
DRIVES=( ${DRIVES[@]/#/"FALSE "} )

TARGET_DRIVE=$(zenity --width 600 --height 400 --title="$TITLE" --text="Select destination disk :" --list --radiolist --column "Disk" --column="Device" --column="Model" --column "Size" "${DRIVES[@]}")

if [ -z "$TARGET_DRIVE" ] || [ ! -e "$TARGET_DRIVE" ]; then
    zenity --error --width=450 --title="$TITLE" --text="You have to select a disk for installation!"
    exit 1
fi

# Check if target disk is partitioned
if sudo parted "$TARGET_DRIVE" print 1 &> /dev/null; then
    zenity --question --width=450 --title="$TITLE" --text="The target drive contains partitions. Are you sure you want to continue?" || exit 1
fi

DISK_SIZE=$(lsblk -dn -o SIZE "$TARGET_DRIVE")
DISK_MODEL=$(cat "/sys/block/${TARGET_DRIVE#/dev/}/device/model" 2>/dev/null || echo "Virtual Disk")

# 2. GUI Confirmation
zenity --question --width=450 --title="$TITLE" \
--text="<b>Installation Summary</b>\n\nTarget: $TARGET_DRIVE - $DISK_MODEL\nSize: $DISK_SIZE\n\n<span foreground='red'><b>WARNING: This will wipe $TARGET_DRIVE.</b></span>\n\nProceed?" || exit 1

# 3. Processing
(
echo "5" ; echo "# Partitioning disk $TARGET_DRIVE..."
[[ $TARGET_DRIVE == *nvme* ]] && PART_EXT="p" || PART_EXT=""
EFI_PART="${TARGET_DRIVE}${PART_EXT}1"
ROOT_PART="${TARGET_DRIVE}${PART_EXT}2"

# Make sure that target drive is not used
if [ "$(findmnt -n -S $EFI_PART)" ] || [ "$(findmnt -n -S $ROOT_PART)" ]; then
    zenity --error --width=450 --title="$TITLE" --text="The target drive is used! Unmount all of its partitions first."
    exit 1
fi

# Partitioning
sudo parted --script "$TARGET_DRIVE" mklabel gpt
sudo parted --script "$TARGET_DRIVE" mkpart primary fat32 1MiB 513MiB
sudo parted --script "$TARGET_DRIVE" set 1 esp on
sudo parted --script "$TARGET_DRIVE" mkpart primary ext4 513MiB 100%
sudo udevadm settle

# Formatting partitions
echo "15" ; echo "# Formatting partitions..."
sudo mkfs.vfat -F32 -n EFI "$EFI_PART" > /dev/null 2>&1
sudo mkfs.ext4 -F -L rootfs "$ROOT_PART" > /dev/null 2>&1

# Mounting target drive
echo "25" ; echo "# Mounting target drive..."
sudo mkdir -p /mnt/target
sudo mount "$ROOT_PART" /mnt/target
sudo mkdir -p /mnt/target/boot/efi
sudo mount "$EFI_PART" /mnt/target/boot/efi

# Cloning live system
echo "30" ; echo "# Copying system files (this may take a few minutes)..."
sudo rsync -aAX --progress \
    --exclude={"/dev/*","/proc/*","/sys/*","/tmp/*","/run/*","/mnt/*","/media/*","/lost+found","/home/*/.cache/*"} \
    / /mnt/target

# Creating fstab (the delayed copy is because I need to use sudo)
echo "80" ; echo "# Configuring system..."
ROOT_UUID=$(lsblk -dn -o UUID "$ROOT_PART")
EFI_UUID=$(lsblk -dn -o UUID "$EFI_PART")
cat <<EOF > "/tmp/fstab"
UUID=$ROOT_UUID / ext4 errors=remount-ro 0 1
UUID=$EFI_UUID /boot/efi vfat umask=0077 0 1
EOF
sudo cp /tmp/fstab /mnt/target/etc/fstab

# Setting up bootloader (Chroot)
echo "85" ; echo "# Setting up bootloader..."
sudo mount --bind /dev /mnt/target/dev
sudo mount --bind /proc /mnt/target/proc
sudo mount --bind /sys /mnt/target/sys
if [ -d "/sys/firmware/efi" ]; then
    BOOT_MODE="uefi"
    sudo mount --bind /sys/firmware/efi/efivars "/mnt/target/sys/firmware/efi/efivars"
else
    BOOT_MODE="bios"
fi
sudo chroot /mnt/target /bin/bash -c "
    update-initramfs -u
    if [ \"$BOOT_MODE\" = \"uefi\" ]; then
        grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=astroberry --recheck --removable
    else
        grub-install --target=i386-pc \"$TARGET_DRIVE\" --recheck
    fi
    update-grub
"

# Unmounting and finalizing
echo "95" ; echo "# Finalizing..."
if [ $BOOT_MODE == "uefi" ]; then
    sudo umount /mnt/target/sys/firmware/efi/efivars
fi
sudo sync

echo "100" ; echo "# Done!"
) | zenity --progress --width=450 --title="$TITLE" --percentage=0 --auto-close --no-cancel

if [ $? -eq 0 ] ; then
    if zenity --question --width=450 --title="$TITLE" --text="Installation successful! Reboot now?" ; then
        sudo reboot
    fi
else
    zenity --error --width=450 --title="$TITLE" --text="Installation failed!"
fi

# Unmounting target partitions
sudo umount /mnt/target/dev /mnt/target/proc /mnt/target/sys
sudo umount /mnt/target/boot/efi
sudo umount /mnt/target

exit 0