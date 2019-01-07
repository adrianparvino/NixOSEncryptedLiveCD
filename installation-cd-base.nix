# This module contains the basic configuration for building a NixOS
# installation CD.

{ config, lib, pkgs, ... }:

with lib;

{
  imports =
    [ ./iso-image.nix

      # Profiles of this basic installation CD.
      <nixpkgs/nixos/modules/profiles/all-hardware.nix>
      <nixpkgs/nixos/modules/profiles/base.nix>
      <nixpkgs/nixos/modules/profiles/installation-device.nix>
    ];

  # ISO naming.
  isoImage.isoName = "${config.isoImage.isoBaseName}-${config.system.nixos.label}-${pkgs.stdenv.hostPlatform.system}.iso";

  isoImage.volumeID = substring 0 11 "NIXOS_ISO";

  # EFI booting
  isoImage.makeEfiBootable = true;

  # USB booting
  isoImage.makeUsbBootable = true;

  # Add Memtest86+ to the CD.
  boot.loader.grub.memtest86.enable = true;

  system.stateVersion = mkDefault "18.03";
}
