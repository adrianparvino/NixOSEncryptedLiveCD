{ vmTools
, runCommand
, utillinux
, cryptsetup
, kmod
}:

vmTools.runInLinuxVM (runCommand "luksSquash"
  {
    SQUASHFS = (import <nixpkgs/nixos> { configuration = <nixos-config>; }).config.system.build.squashfsStore;

    nativeBuildInputs = [ utillinux cryptsetup kmod ];
    __impure = true;
  }
  ''
    BLOCKS=$(du -B 512 $(realpath $SQUASHFS) | cut -d $'\t' -f1)

    modprobe loop

    rmdir $out
    fallocate -x -l $(( 512 * ($BLOCKS + 4096) )) $out

    cryptsetup luksFormat $out <<< PASSPHRASE
    cryptsetup luksOpen $out cryptbackup <<< PASSPHRASE

    dd if=$SQUASHFS of=/dev/mapper/cryptbackup bs=512

    cryptsetup luksClose cryptbackup
  '')
