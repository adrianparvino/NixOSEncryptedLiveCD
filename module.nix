{ pkgs, ... }:
let
  restore = with pkgs; runCommand "restore" {} ''
    mkdir -p $out
    echo {} > $out/default.nix
    cp ${./configuration.nix} $out/configuration.nix
    cp ${./args.nix}  $out/args.nix
    cp ${./install.sh} $out/install.sh
  '';
  create-image = with pkgs; runCommand "create-image.sh" {
    nativeBuildInputs = [ makeWrapper ] ;
  } ''
    makeWrapper ${./create-image.sh} $out/bin/create-image.sh \
      --prefix PATH ":" ${lib.makeBinPath [ cryptsetup dosfstools e2fsprogs grub2 syslinux utillinux ]} \
      --prefix NIX_PATH ":" restore=${restore}
  '';
in
{
  environment.systemPackages = [ create-image ];
}
