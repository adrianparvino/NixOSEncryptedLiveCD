#!/usr/bin/env bash

nix-instantiate --find-file restore >/dev/null 2>/dev/null ||
    export NIX_PATH=restore=./.${NIX_PATH:+:$NIX_PATH}

STAGEs=()

while [ "$#" -gt 0 ]; do
    case "$1" in
        --debug)
            DEBUG=
    esac
    shift
done

formatImage()
{
    {
        echo g      # Create a new empty GPT partition table

        echo n      # Add a new partition
        echo        # Partition number for BIOS boot
        echo        # First sector (default)
        echo +1M    # Last sector

        echo n      # Add a new partition
        echo        # Partition number for /boot
        echo        # First sector (default)
        echo +64M   # Last sector

        echo n      # Add a new partition
        echo        # Partition number for /
        echo        # First sector (default)
        echo        # Last sector (default)

        echo t
        echo 1
        echo 4

        echo t
        echo 2
        echo 1

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
    truncate -s 4GB "$out"
    formatImage
    # TODO, add encryption
    LOOP_DEVICE="$(losetup --show -f "$out")"
    # Temporary fix for https://github.com/torvalds/linux/commit/628bd85947091830a8c4872adfd5ed1d515a9cf2
    partx -u $LOOP_DEVICE
    DISK_IMAGE="${LOOP_DEVICE}p"
    STAGEs=( "losetup" "${STAGEs[@]}" )

    ROOT_MNT="${out}mnt"
    mkdir -p "$ROOT_MNT"
fi

mkfs.vfat "${DISK_IMAGE}2"
mkfs.f2fs "${DISK_IMAGE}3"

BOOT_DEV="/dev/disk/by-uuid/$(blkid -o value -s UUID "${DISK_IMAGE}2")"
ROOT_DEV="/dev/disk/by-uuid/$(blkid -o value -s UUID "${DISK_IMAGE}3")"

STAGEs=( "outmnt" "${STAGEs[@]}" )

mount "$ROOT_DEV" "$ROOT_MNT"
mkdir "$ROOT_MNT/boot"
mount "$BOOT_DEV" "$ROOT_MNT/boot"

read -r -d '' CONFIGURATION <<EOF
{
  imports =
    [ <restore/configuration.nix>
      /etc/nixos/duplicity-backup-config.nix
    ];

  NixOSEncryptedLiveCD.rootdevice = "$ROOT_DEV";
  NixOSEncryptedLiveCD.bootdevice = "$BOOT_DEV";

  ${DEBUG+NixOSEncryptedLiveCD.debug = true;}
}
EOF

DRVs=$(nix-instantiate '<nixpkgs/nixos>' -A system --arg configuration "$CONFIGURATION")
nix build $DRVs --no-link
CLOSURE="$(nix-store -q --outputs $DRVs)" #-I nixpkgs/nixos=nixos

grub-install --target=i386-pc --boot-directory "$ROOT_MNT/boot" "$out"
nixos-install --system "$CLOSURE" --root $(realpath "$ROOT_MNT") --no-root-passwd

cp --parents -r /var/keys/duplicity "$ROOT_MNT"
