{ vmTools
, runCommand
, utillinux
, cryptsetup
, kmod
}:

vmTools.runInLinuxVM ((runCommand "luksSquash"
  {
    SQUASHFS = (import <nixpkgs/nixos> { configuration = ./iso.nix; }).config.system.build.squashfsStore;

    nativeBuildInputs = [ utillinux cryptsetup kmod ];
  }
  ''
    BLOCKS=$(du -B 512 $(realpath $SQUASHFS) | cut -d $'\t' -f1)

    modprobe loop

    rmdir $out
    # dd if=/dev/zero of=$out bs=512 count=$(( $BLOCKS + 8192 ))
    fallocate -x -l $(( 512 * ($BLOCKS + 8192) )) $out

    cryptsetup luksFormat $out <<< PASSPHRASE
    cryptsetup luksOpen $out cryptbackup <<< PASSPHRASE

    dd if=$SQUASHFS of=/dev/mapper/cryptbackup bs=512

    cryptsetup luksClose cryptbackup
  '').overrideAttrs (_: { __impure = true; }))
