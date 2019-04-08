#!/usr/bin/env bash

nix-instantiate --find-file restore >/dev/null ||
    export NIX_PATH=restore=./.${NIX_PATH:+:$NIX_PATH}

STAGEs=()

formatImage()
{
    {
        echo o      # Create a new empty GPT partition table

        echo n      # Add a new partition
        echo p      # Primary
        echo 1      # Partition number for /boot
        echo        # First sector (default)
        echo +128M  # Last sector

        echo n      # Add a new partition
        echo p      # Primary
        echo 2      # Partition number for /
        echo        # First sector (default)
        echo        # Last sector (default)

        echo a      # Add bootable flag
        echo 1      # to the boot partition

        echo w      # Write changes
    } | fdisk "$out"
}

atexit ()
{
    while (( ${#STAGEs[@]} )); do
        case ${STAGEs[0]} in
            "losetup"):
                losetup -d "$LOOP_DEVICE"
                ;;
            "outmnt"):
                umount -R "$ROOT_MNT"
                rmdir "$ROOT_MNT"
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
    formatImage
    DISK_IMAGE="$out"

    ROOT_MNT=$(mktemp -d)
# If $out is not a block device, but it exists, then abort
elif [ -f "$out" ]; then
    printf "%s already exists! Exiting." "$out"
    exit 1
# If $out is not a block device, and doesn't exist, then create it
else
    truncate -s 8G "$out"
    formatImage
    # TODO, add encryption
    LOOP_DEVICE="$(losetup --show -f "$out")"
    # Temporary fix for https://github.com/torvalds/linux/commit/628bd85947091830a8c4872adfd5ed1d515a9cf2
    partx -u $LOOP_DEVICE
    DISK_IMAGE="${LOOP_DEVICE}p"
    STAGEs=( "losetup" "${STAGEs[@]}" )

    ROOT_MNT="${out}mnt"
fi

mkfs.vfat "${DISK_IMAGE}1"
mkfs.ext4 "${DISK_IMAGE}2"

while [ "${BOOT_DEV}" == "" -o "${ROOT_DEV}" == "" ]; do
    for i in /dev/disk/by-uuid/*; do
        if [ $(realpath "$i") == "${DISK_IMAGE}1" ]; then
            BOOT_DEV="$i"
        elif [ $(realpath "$i") == "${DISK_IMAGE}2" ]; then
            ROOT_DEV="$i"
        fi
    done
done

mkdir -p "$ROOT_MNT"
STAGEs=( "outmnt" "${STAGEs[@]}" )

mount "${DISK_IMAGE}2" "$ROOT_MNT"

mkdir "$ROOT_MNT/boot"
mount "${DISK_IMAGE}1" "$ROOT_MNT/boot"

read -r -d '' CONFIGURATION <<EOF
{
  imports =
    [ <restore/configuration.nix>
      /etc/nixos/duplicity-backup-config.nix
    ];

  rootdevice="$ROOT_DEV";
  bootdevice="$BOOT_DEV";
}
EOF

DRVs=$(nix-instantiate '<nixpkgs/nixos>' -A system --arg configuration "$CONFIGURATION")
nix build $DRVs
CLOSURE="$(nix-store -q --outputs $DRVs)" #-I nixpkgs/nixos=nixos

grub-install --target=i386-pc --boot-directory "$ROOT_MNT/boot" "$out"
nixos-install --system "$CLOSURE" --root $(realpath "$ROOT_MNT") --no-root-passwd

cp --parents -r /var/keys/duplicity "$ROOT_MNT"
