{ pkgs, ... }:

{
  imports = [ ./configuration.nix ];

  system.activationScripts.populateEtc = ''
    touch /etc/wpa_supplicant.conf

    mkdir -p /etc/nixos
    mkdir -p /var/keys
    cp -r /tmp/xchg/var/keys/duplicity /var/keys/duplicity
    cp ${./configuration.nix} /etc/nixos/configuration.nix
    cp ${/etc/nixos/duplicity-backup-config.nix} /etc/nixos/duplicity-backup-config.nix
    mkdir -p /home/myrl/Development
    cp -r ${/home/myrl/Development/nix-duplicity-backup} /home/myrl/Development/nix-duplicity-backup
  '';
}
