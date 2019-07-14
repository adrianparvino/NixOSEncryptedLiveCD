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
      type = types.nullOr types.string;
      default = null;
    };
  };
}
