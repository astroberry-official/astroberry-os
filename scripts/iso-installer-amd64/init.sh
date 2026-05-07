#!/bin/sh
# Standard mounts
mount -t proc proc /proc
mount -t sysfs sys /sys
mount -t devtmpfs dev /dev
modprobe efivarfs
mount -t efivarfs efivarfs /sys/firmware/efi/efivars

# Silence the kernel output
echo "1 1 1 1" > /proc/sys/kernel/printk

# Start the udev daemon
/lib/systemd/systemd-udevd --daemon

# Clear the screen
clear

# Initialize hardware
udevadm trigger --action=add --type=subsystems
udevadm settle
udevadm trigger --action=add --type=devices
udevadm settle

clear
echo "--- Searching for ISO ---"
mkdir -p /cdrom

# Use the label you actually defined in grub-mkrescue (-V)
mount /dev/disk/by-label/astroberrycd /cdrom > /dev/null 2>&1

if [ $? -eq 0 ]; then
    echo "--- CDROM Mounted. Starting Deployment ---"
    # Match the path you used in your 'Create ISO rootfs' step
    if [ -f /cdrom/installer/deploy.sh ]; then
        /bin/bash /cdrom/installer/deploy.sh
    else
        echo "ERROR: deploy.sh not found at /cdrom/installer/deploy.sh"
        ls -R /cdrom
    fi
else
    echo "ERROR: Could not mount ISO by label 'astroberrycd'"
    echo "Available disks:"
    ls /dev/disk/by-label/
fi

echo "--- Script finished. Dropping to shell to prevent panic ---"
exec /bin/sh