{ vmTools
, stdenv
, utillinux
, cryptsetup
, kmod
}:

fileSystem:

vmTools.runInLinuxVM (stdenv.mkDerivation
  {
    name =  "wrap-luks";

    buildCommand = builtins.readFile ./wrap-luks.sh;

    FILE_SYSTEM=fileSystem;

    PASSPHRASE = "PASSPHRASE";

    nativeBuildInputs = [ utillinux cryptsetup kmod ];
    __impure = true;
  })
