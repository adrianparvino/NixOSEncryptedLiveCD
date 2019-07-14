chvt 7

until ip route | grep default; do
    wpa_cli scan on
    menu=()
    while read -r bssid frequency signal_level flags ssid; do
        menu+=( "$ssid" "$bssid $frequency $signal_level $flags" )
    done < <(wpa_cli scan_results | tail -n +3)
    menu+=( "rescan" "" )
    SSID=$(dialog --menu "Network Name" 0 0 0 "${menu[@]}" 2>&1 1>/dev/tty)
    SSID=${SSID:-rescan}
    if [ "$SSID" = "rescan" ]; then
        continue
    fi
    PSK=$(dialog --inputbox "Password" 0 0 2>&1 1>/dev/tty)
    NETWORK=$(wpa_cli add_network | tail -n1)
    wpa_cli set_network $NETWORK ssid "\"$SSID\"" >/dev/null
    wpa_cli set_network $NETWORK psk "\"$PSK\"" >/dev/null
    wpa_cli enable_network $NETWORK >/dev/null
    sleep 10
done
wpa_cli scan off || true

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

  nix.binaryCaches = [ "https://cache.nixos.org" ${DEBUG+''$DEBUG''} ];
  nix.requireSignedBinaryCaches = false;

  boot.loader.grub.device = "nodev";
}
EOF

DRV=$(nix-instantiate '<nixpkgs/nixos>' --arg configuration "$CONFIGURATION" -A system)
nix build $DRV
CLOSURE=$(nix-store -q --outputs $DRV)
nixos-install --system "$CLOSURE" --no-bootloader --no-root-passwd

read -r -d '' CONFIGURATION <<EOF || true
{ lib, ... }:
{
  imports = [ /etc/nixos/configuration.nix ];

  services.duplicity-backup.enableRestore = true;

  boot.loader.grub.device = lib.mkDefault "/dev/${DEVICE_NAME}";
}
EOF

# Some Nix operations require /tmp to function
mkdir -p /mnt/tmp

# Some nix operations require /tmp to function
mkdir -p /mnt/var/run/nscd
mount --bind /var/run/nscd /mnt/var/run/nscd

DRV=$(nixos-enter -- nix-instantiate '<nixpkgs/nixos>' --arg configuration "$CONFIGURATION" -A system)
nix build --store /mnt $DRV
CLOSURE=$(nix-store --store /mnt -q --outputs $DRV)
nixos-install --system "$CLOSURE" --no-root-passwd

cp --parents -r /var/keys/duplicity /mnt
