set -x

chvt 7

# Credit to geirha@Freenode#bash
menu=()
while read -r name size model; do
  menu+=( "$name" "$size $model" )
done < <(lsblk -dn -o NAME,SIZE,MODEL)

DEVICE_NAME=$(dialog --menu "Choose" 0 0 0 "${menu[@]}" 2>&1 1>/dev/tty)

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
} | fdisk "/dev/${DEVICE_NAME}"

yes n | mkfs.vfat "/dev/${DEVICE_NAME}1"
yes n | mkfs.ext4 "/dev/${DEVICE_NAME}2"

mkdir -p /mnt
mount "/dev/${DEVICE_NAME}2" /mnt
mkdir /mnt/boot
mount "/dev/${DEVICE_NAME}1" /mnt/boot

duplicity-restore-system

nixos-generate-config --root /mnt

read -r -d '' CONFIGURATION <<EOF || true
{
  imports = [ /mnt/etc/nixos/hardware-configuration.nix ];

  boot.loader.grub.device = "nodev";
}
EOF

CLOSURE=$(nix-build '<nixpkgs/nixos>' --arg configuration "$CONFIGURATION" --no-out-link -A system)
nixos-install --system "$CLOSURE"

read -r -d '' CONFIGURATION <<EOF || true
{ lib, ... }:
{
  imports = [ /etc/nixos/configuration.nix ];

  boot.loader.grub.device = lib.mkDefault "/dev/sdb";
}
EOF

DRV=$(nixos-enter -- nix-instantiate '<nixpkgs/nixos>' --arg configuration "$CONFIGURATION" -A system)
CLOSURE=$(nix-build --store /mnt "$DRV")
nixos-install --system "$CLOSURE"
