#!/usr/bin/env bash

nix-instantiate --find-file restore >/dev/null 2>/dev/null ||
    export NIX_PATH=restore=./.${NIX_PATH:+:$NIX_PATH}

STAGEs=()

while [ "$#" -gt 0 ]; do
    case "$1" in
        --debug)
            shift
            DEBUG="$1"
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
                umount "$ROOT_MNT/boot"
                umount "$ROOT_MNT"
                cryptsetup close "$LUKS_NAME"
                rmdir "$ROOT_MNT/boot"
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
    DISK="$out"

    ROOT_MNT=$(mktemp -d)
    LUKS_NAME="$(basename "$ROOT_MNT")_root"
# If $out is not a block device, but it exists, then abort
elif [ -f "$out" ]; then
    printf "%s already exists! Exiting." "$out"
    exit 1
# If $out is not a block device, and doesn't exist, then create it
else
    truncate -s 4GB "$out"
    formatImage
    STAGEs=( "losetup" "${STAGEs[@]}" )
    # TODO, add encryption
    LOOP_DEVICE="$(losetup --show -f "$out")"
    # Temporary fix for https://github.com/torvalds/linux/commit/628bd85947091830a8c4872adfd5ed1d515a9cf2
    partx -u $LOOP_DEVICE

    DISK="${LOOP_DEVICE}"
    SEP=p

    ROOT_MNT="${out}mnt"
    mkdir -p "$ROOT_MNT"
    LUKS_NAME="$(basename "$out")_root"
fi

mkfs.vfat "${DISK}${SEP}2"
cryptsetup luksFormat "${DISK}${SEP}3"
cryptsetup luksOpen "${DISK}${SEP}3" "$LUKS_NAME"
mkfs.ext4 "/dev/mapper/$LUKS_NAME"

BOOT_DEV="/dev/disk/by-uuid/$(blkid -o value -s UUID "${DISK}${SEP}2")"
ROOT_DEV="/dev/mapper/$LUKS_NAME"
ENC_ROOT_DEV="/dev/disk/by-uuid/$(blkid -o value -s UUID "${DISK}${SEP}3")"

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

  boot.initrd.luks.devices = [
    {
      name = "$LUKS_NAME";
      device = "$ENC_ROOT_DEV";
      preLVM = true;
      allowDiscards = true;
    }
  ];

  ${DEBUG+NixOSEncryptedLiveCD.debug = ''$DEBUG'';}
}
EOF

DRVs=$(nix-instantiate '<nixpkgs/nixos>' -A system --arg configuration "$CONFIGURATION")
nix build $DRVs --no-link
CLOSURE="$(nix-store -q --outputs $DRVs)" #-I nixpkgs/nixos=nixos

grub-install --target=i386-pc --boot-directory "$ROOT_MNT/boot" "$DISK"
nixos-install --system "$CLOSURE" --root $(realpath "$ROOT_MNT") --no-root-passwd

cp --parents -r /var/keys/duplicity "$ROOT_MNT"
