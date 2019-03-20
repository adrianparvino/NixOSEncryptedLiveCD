# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, lib, ... }:

with lib;
{
  imports =
    [ <nixpkgs/nixos/modules/profiles/all-hardware.nix>
      <nixpkgs/nixos/modules/profiles/base.nix>

      ./args.nix
    ];

  services.duplicity-backup.enableRestore = true;
  services.duplicity-backup.target = "/mnt";

  fileSystems."/" =
    { device = config.rootdevice;
      fsType = "ext4";
    };

  fileSystems."/boot" =
    { device = config.bootdevice;
      fsType = "vfat";
    };

  boot.loader.grub.enable = true;
  boot.loader.grub.device = "nodev";

  users.users.root.initialHashedPassword = "";

  # This value determines the NixOS release with which your system is to be
  # compatible, in order to avoid breaking some software such as database
  # servers. You should change this only after NixOS release notes say you
  # should.
  system.stateVersion = "18.09"; # Did you read the comment?
}
