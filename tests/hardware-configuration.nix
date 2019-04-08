{ pkgs, ... }:
{
  imports = [
    <nixpkgs/nixos/modules/profiles/all-hardware.nix>
    <nixpkgs/nixos/modules/profiles/base.nix>
  ];

  users.users.root.initialHashedPassword = "";
}
