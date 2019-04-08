# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, lib, ... }:

with lib;
{
  imports =
    [
      /etc/nixos/duplicity-backup-config.nix
      ./hardware-configuration.nix
    ];

  services.duplicity-backup.enableBackup = true;

  environment.systemPackages = with pkgs; [ emacs ];

  # This value determines the NixOS release with which your system is to be
  # compatible, in order to avoid breaking some software such as database
  # servers. You should change this only after NixOS release notes say you
  # should.
  system.stateVersion = "18.09"; # Did you read the comment?
}
