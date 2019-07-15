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

  services.duplicity-system.restorationImage = true;

  services.duplicity-backup.enableRestore = true;
  services.duplicity-backup.target = "/mnt";

  environment.etc."wpa_supplicant.conf".text = ''
    ctrl_interface=/var/run/wpa_supplicant
    update_config=1
  '';

  fileSystems."/" =
    { device = config.NixOSEncryptedLiveCD.rootdevice;
      fsType = "f2fs";
    };

  fileSystems."/boot" =
    { device = config.NixOSEncryptedLiveCD.bootdevice;
      fsType = "vfat";
    };

  boot.loader.grub.enable = true;
  boot.loader.grub.device = "nodev";

  networking.nameservers = [ "8.8.8.8" "1.1.1.1" ];
  networking.wireless.enable = true;

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
    } // lib.optionalAttrs (config.NixOSEncryptedLiveCD.debug == null) {
      TTYReset = "yes";
      TTYVTDisallocate = true;
    };

    environment = {
      NIX_PATH = builtins.concatStringsSep ":" config.nix.nixPath;
    } // lib.optionalAttrs (config.NixOSEncryptedLiveCD.debug != null) {
      DEBUG = config.NixOSEncryptedLiveCD.debug;
    };

    path = with pkgs; let
      inherit (config.system.build) nixos-install nixos-enter nixos-generate-config;
    in [
      dialog
      dosfstools
      e2fsprogs
      iproute
      kbd
      nix
      nixos-enter
      nixos-generate-config
      nixos-install
      utillinux
      wpa_supplicant

      config.services.duplicity-backup.archives.system.script
    ];

    script = builtins.readFile ./install.sh;
  };

  nix.binaryCaches = [
    "https://cache.nixos.org"
  ] ++ lib.optional (config.NixOSEncryptedLiveCD.debug != null) config.NixOSEncryptedLiveCD.debug;
  nix.requireSignedBinaryCaches = false;

  nixpkgs.config.packageOverrides = pkgs: with pkgs; {
    pinentry = pinentry_ncurses;
    duplicity = duplicity.overrideAttrs ({propagatedBuildInputs, ...}: { propagatedBuildInputs = lib.filter (x: x != pkgs.python2Packages.pygobject3) propagatedBuildInputs; });
  };

  # This value determines the NixOS release with which your system is to be
  # compatible, in order to avoid breaking some software such as database
  # servers. You should change this only after NixOS release notes say you
  # should.
  system.stateVersion = "18.09"; # Did you read the comment?
}
