{ lib, ... }:

with lib;
{
  options.NixOSEncryptedLiveCD = {
    rootdevice = mkOption {
      type = types.string;
    };

    bootdevice = mkOption {
      type = types.string;
    };

    debug = mkOption {
      type = types.bool;
      default = false;
    };
  };
}
