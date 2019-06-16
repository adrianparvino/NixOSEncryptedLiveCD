chvt 7

# Credit to geirha@Freenode#bash
menu=()
while read -r name size model; do
  menu+=( "$name" "$size $model" )
done < <(lsblk -dn -o NAME,SIZE,MODEL)

DEVICE_NAME=$(dialog --menu "Choose" 0 0 0 "${menu[@]}" 2>&1 1>/dev/tty)

{
    echo g      # Create a new empty GPT partition table

    echo n      # Add a new partition
    echo        # Partition number for BIOS boot
    echo        # First sector (default)
    echo +1M    # Last sector

    echo n      # Add a new partition
    echo        # Partition number for /boot
    echo        # First sector (default)
    echo +128M  # Last sector

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
} | fdisk "/dev/${DEVICE_NAME}"

yes n | mkfs.vfat "/dev/${DEVICE_NAME}2" || true
yes n | mkfs.ext4 "/dev/${DEVICE_NAME}3" || true

mkdir -p /mnt
mount "/dev/${DEVICE_NAME}3" /mnt
mkdir /mnt/boot
mount "/dev/${DEVICE_NAME}2" /mnt/boot

duplicity-restore-system

nixos-generate-config --root /mnt

read -r -d '' CONFIGURATION <<EOF || true
{
  imports = [ /mnt/etc/nixos/hardware-configuration.nix ];

  boot.loader.grub.device = "nodev";
}
EOF

DRV=$(nix-instantiate '<nixpkgs/nixos>' --arg configuration "$CONFIGURATION" -A system)
nix build $DRV
CLOSURE=$(nix-store -q --outputs $DRV)
nixos-install --system "$CLOSURE" --no-root-passwd

read -r -d '' CONFIGURATION <<EOF || true
{ lib, ... }:
{
  imports = [ /etc/nixos/configuration.nix ];

  boot.loader.grub.device = lib.mkDefault "/dev/${DEVICE_NAME}";
}
EOF

DRV=$(nixos-enter -- nix-instantiate '<nixpkgs/nixos>' --arg configuration "$CONFIGURATION" -A system)
DRV=${DRV#/mnt} # Remove /mnt prefix
nix build --store /mnt $DRV
CLOSURE=$(nix-store --store /mnt -q --outputs $DRV)
nixos-install --system "$CLOSURE" --no-root-passwd
