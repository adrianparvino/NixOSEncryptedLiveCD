{ lib, ... }:

with lib;
{
  options = {
    rootdevice = mkOption {
      type = types.string;
    };

    bootdevice = mkOption {
      type = types.string;
    };
  };
}
