# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, lib, ... }:

with lib;
{
  imports =
    [ <nixpkgs/nixos/modules/profiles/all-hardware.nix>
      <nixpkgs/nixos/modules/profiles/base.nix>
      <nixpkgs/nixos/modules/installer/cd-dvd/channel.nix>

      ./args.nix
    ];

  services.duplicity-backup.enableRestore = true;
  services.duplicity-backup.target = "/mnt";

  fileSystems."/" =
    { device = config.rootdevice;
      fsType = "f2fs";
    };

  fileSystems."/boot" =
    { device = config.bootdevice;
      fsType = "vfat";
    };

  boot.loader.grub.enable = true;
  boot.loader.grub.device = "nodev";

  users.users.root.initialHashedPassword = "";

  boot.extraTTYs = [ "tty7" ];

  systemd.services.baka = {
    after = [ "default.target" ];
    wantedBy = [ "default.target" ];

    serviceConfig = {
      StandardInput = "tty";
      StandardOutput = "tty";
      StandardError = "tty";
      TTYPath = "/dev/tty7";
      TTYReset = "yes";
      TTYVTDisallocate = true;
    };
    environment.NIX_PATH = builtins.concatStringsSep ":" config.nix.nixPath;

    path = with pkgs; let
      inherit (config.system.build) nixos-install nixos-enter nixos-generate-config;
    in [
      kbd
      dialog
      utillinux
      dosfstools
      e2fsprogs
      nix
      nixos-install
      nixos-enter
      nixos-generate-config
      config.services.duplicity-backup.archives.system.script
    ];

    script = builtins.readFile ./install.sh;
  };

  # This value determines the NixOS release with which your system is to be
  # compatible, in order to avoid breaking some software such as database
  # servers. You should change this only after NixOS release notes say you
  # should.
  system.stateVersion = "18.09"; # Did you read the comment?
}
