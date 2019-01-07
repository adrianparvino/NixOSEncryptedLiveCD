{config, pkgs, ...}:
{
  imports = [
    ./installation-cd-minimal.nix

    # Provide an initial copy of the NixOS channel so that the user
    # doesn't need to run "nix-channel --update" first.
    <nixpkgs/nixos/modules/installer/cd-dvd/channel.nix>
  ];
}
