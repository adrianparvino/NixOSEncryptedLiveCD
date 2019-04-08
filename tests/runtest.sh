TMPDIR=$(realpath ./nix-vm)
RUNNER=$(nix-build '<nixpkgs/nixos>' -I nixos-config=test-configuration.nix -A vm)

sudo rm nixos.qcow2
sudo cp --parents -r /var/keys/duplicity ./nix-vm/xchg/
sudo USE_TMPDIR=0 TMPDIR=$TMPDIR $RUNNER/bin/run-nixos-vm
