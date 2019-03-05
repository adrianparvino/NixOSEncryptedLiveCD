#!/usr/bin/env bash

STAGEs=()

atexit ()
{
    while (( ${#STAGEs[@]} )); do
        case ${STAGEs[0]} in
            "losetup"):
                losetup -d "$LOOP_DEVICE"
                ;;
            "outmnt"):
                umount -R "${out}mnt"
                rmdir "${out}mnt"
                ;;
            *):
                echo "Invalid atexit hook" >&2
                ;;
        esac
        STAGEs=( "${STAGEs[@]:1}" )
    done
}
trap atexit EXIT

# If $out is unset or empty, out=result
out="${out:-result}"

# If $out is a block device, do nothing
if [ -b "$out" ]; then
    :
# If $out is not a block device, but it exists, then abort
elif [ -f "$out" ]; then
    printf "%s already exists! Exiting." "$out"
    exit 1
# If $out is not a block device, and doesn't exist, then create it
else
    truncate -s 8G $out
fi

# Create file if it is not a block device
{
    echo o    # Create a new empty GPT partition table

    echo n    # Add a new partition
    echo p    # Primary
    echo 1    # Partition number for /boot
    echo      # First sector (default)
    echo +1G  # Last sector

    echo n    # Add a new partition
    echo p    # Primary
    echo 2    # Partition number for /
    echo      # First sector (default)
    echo      # Last sector (default)

    echo a    # Add bootable flag
    echo 1    # to the boot partition

    echo w    # Write changes
} | fdisk "$out"

# TODO, add encryption
LOOP_DEVICE="$(losetup --show -f "$out")"
# Temporary fix for https://github.com/torvalds/linux/commit/628bd85947091830a8c4872adfd5ed1d515a9cf2
partx -u $LOOP_DEVICE
STAGEs=( "losetup" "${STAGEs[@]}" )

mkfs.vfat "${LOOP_DEVICE}p1"
mkfs.ext4 "${LOOP_DEVICE}p2"

while [ "${BOOT_DEV}" == "" -o "${ROOT_DEV}" == "" ]; do
    for i in /dev/disk/by-uuid/*; do
        if [ $(realpath "$i") == "${LOOP_DEVICE}p1" ]; then
            BOOT_DEV="$i"
        elif [ $(realpath "$i") == "${LOOP_DEVICE}p2" ]; then
            ROOT_DEV="$i"
        fi
    done
done

mkdir -p "${out}mnt"
STAGEs=( "outmnt" "${STAGEs[@]}" )

mount "${LOOP_DEVICE}p2" "${out}mnt"

mkdir "${out}mnt/boot"
mount "${LOOP_DEVICE}p1" "${out}mnt/boot"

read -r -d '' CONFIGURATION <<EOF
{ imports = [ ./configuration.nix ];

  rootdevice="$ROOT_DEV";
  bootdevice="$BOOT_DEV";
}
EOF


CLOSURE="$(nix-build '<nixpkgs/nixos>' -A system --no-out-link --arg configuration "$CONFIGURATION")" #-I nixpkgs/nixos=nixos

grub-install --target=i386-pc --boot-directory "${out}mnt/boot" "$out"
nixos-install --system "$CLOSURE" --root $(realpath "${out}mnt") --no-root-passwd
