# This module provides the proprietary NVIDIA X11 / OpenGL drivers.

{ config, lib, pkgs, pkgs_i686, ... }:

with lib;

let

  drivers = config.services.xserver.videoDrivers;

  # FIXME: should introduce an option like
  # ‘hardware.video.nvidia.package’ for overriding the default NVIDIA
  # driver.
  nvidiaForKernel = kernelPackages:
    if elem "nvidia" drivers then
        kernelPackages.nvidia_x11
    else if elem "nvidiaBeta" drivers then
        kernelPackages.nvidia_x11_beta
    else if elem "nvidiaLegacy304" drivers then
      kernelPackages.nvidia_x11_legacy304
    else if elem "nvidiaLegacy340" drivers then
      kernelPackages.nvidia_x11_legacy340
    else null;

  nvidia_x11 = nvidiaForKernel config.boot.kernelPackages;
  nvidia_libs32 = (nvidiaForKernel pkgs_i686.linuxPackages).override { libsOnly = true; kernel = null; };

  enabled = nvidia_x11 != null;

  cfg = config.hardware.nvidia;
  optimusCfg = cfg.optimus_prime;
in

{
  options = {
    hardware.nvidia.modesetting.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Enable kernel modesetting when using the NVIDIA proprietary driver.

        Enabling this fixes screen tearing when using Optimus via PRIME (see
        <option>hardware.nvidia.optimus_prime.enable</option>. This is not enabled
        by default because it is not officially supported by NVIDIA and would not
        work with SLI.
      '';
    };

    hardware.nvidia.optimus_prime.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Enable NVIDIA Optimus support using the NVIDIA proprietary driver via PRIME.
        If enabled, the NVIDIA GPU will be always on and used for all rendering,
        while enabling output to displays attached only to the integrated Intel GPU
        without a multiplexer.

        Note that this option only has any effect if the "nvidia" driver is specified
        in <option>services.xserver.videoDrivers</option>, and it should preferably
        be the only driver there.

        If this is enabled, then the bus IDs of the NVIDIA and Intel GPUs have to be
        specified (<option>hardware.nvidia.optimus_prime.nvidiaBusId</option> and
        <option>hardware.nvidia.optimus_prime.intelBusId</option>).

        If you enable this, you may want to also enable kernel modesetting for the
        NVIDIA driver (<option>hardware.nvidia.modesetting.enable</option>) in order
        to prevent tearing.

        Note that this configuration will only be successful when a display manager
        for which the <option>services.xserver.displayManager.setupCommands</option>
        option is supported is used; notably, SLiM is not supported.
      '';
    };

    hardware.nvidia.optimus_prime.nvidiaBusId = lib.mkOption {
      type = lib.types.string;
      default = "";
      example = "PCI:1:0:0";
      description = ''
        Bus ID of the NVIDIA GPU. You can find it using lspci; for example if lspci
        shows the NVIDIA GPU at "01:00.0", set this option to "PCI:1:0:0".
      '';
    };

    hardware.nvidia.optimus_prime.intelBusId = lib.mkOption {
      type = lib.types.string;
      default = "";
      example = "PCI:0:2:0";
      description = ''
        Bus ID of the Intel GPU. You can find it using lspci; for example if lspci
        shows the Intel GPU at "00:02.0", set this option to "PCI:0:2:0".
      '';
    };
  };

  config = mkIf enabled {
    assertions = [
      {
        assertion = with config.services.xserver.displayManager; gdm.enable -> !gdm.wayland;
        message = "NVidia drivers don't support wayland";
      }
      {
        assertion = !optimusCfg.enable ||
          (optimusCfg.nvidiaBusId != "" && optimusCfg.intelBusId != "");
        message = ''
          When NVIDIA Optimus via PRIME is enabled, the GPU bus IDs must configured.
        '';
      }
    ];

    # If Optimus/PRIME is enabled, we:
    # - Specify the configured NVIDIA GPU bus ID in the Device section for the
    #   "nvidia" driver.
    # - Add the AllowEmptyInitialConfiguration option to the Screen section for the
    #   "nvidia" driver, in order to allow the X server to start without any outputs.
    # - Add a separate Device section for the Intel GPU, using the "modesetting"
    #   driver and with the configured BusID.
    # - Reference that Device section from the ServerLayout section as an inactive
    #   device.
    # - Configure the display manager to run specific `xrandr` commands which will
    #   configure/enable displays connected to the Intel GPU.

    services.xserver.drivers = singleton {
      name = "nvidia";
      modules = [ nvidia_x11.bin ];
      libPath = [ nvidia_x11 ];
      deviceSection = optionalString optimusCfg.enable
        ''
          BusID "${optimusCfg.nvidiaBusId}"
        '';
      screenSection =
        ''
          Option "RandRRotation" "on"
          ${optionalString optimusCfg.enable "Option \"AllowEmptyInitialConfiguration\""}
        '';
    };

    services.xserver.extraConfig = optionalString optimusCfg.enable
      ''
        Section "Device"
          Identifier "nvidia-optimus-intel"
          Driver "modesetting"
          BusID  "${optimusCfg.intelBusId}"
          Option "AccelMethod" "none"
        EndSection
      '';
    services.xserver.serverLayoutSection = optionalString optimusCfg.enable
      ''
        Inactive "nvidia-optimus-intel"
      '';

    services.xserver.displayManager.setupCommands = optionalString optimusCfg.enable ''
      # Added by nvidia configuration module for Optimus/PRIME.
      ${pkgs.xorg.xrandr}/bin/xrandr --setprovideroutputsource modesetting NVIDIA-0
      ${pkgs.xorg.xrandr}/bin/xrandr --auto
    '';

    environment.etc."nvidia/nvidia-application-profiles-rc" = mkIf nvidia_x11.useProfiles {
      source = "${nvidia_x11.bin}/share/nvidia/nvidia-application-profiles-rc";
    };

    hardware.opengl.package = nvidia_x11.out;
    hardware.opengl.package32 = nvidia_libs32.out;

    environment.systemPackages = [ nvidia_x11.bin nvidia_x11.settings ]
      ++ lib.filter (p: p != null) [ nvidia_x11.persistenced ];

    boot.extraModulePackages = [ nvidia_x11.bin ];

    # nvidia-uvm is required by CUDA applications.
    boot.kernelModules = [ "nvidia-uvm" ] ++
      lib.optionals config.services.xserver.enable [ "nvidia" "nvidia_modeset" "nvidia_drm" ];

    # If requested enable modesetting via kernel parameter.
    boot.kernelParams = optional cfg.modesetting.enable "nvidia-drm.modeset=1";

    # Create /dev/nvidia-uvm when the nvidia-uvm module is loaded.
    services.udev.extraRules =
      ''
        KERNEL=="nvidia", RUN+="${pkgs.runtimeShell} -c 'mknod -m 666 /dev/nvidiactl c $(grep nvidia-frontend /proc/devices | cut -d \  -f 1) 255'"
        KERNEL=="nvidia_modeset", RUN+="${pkgs.runtimeShell} -c 'mknod -m 666 /dev/nvidia-modeset c $(grep nvidia-frontend /proc/devices | cut -d \  -f 1) 254'"
        KERNEL=="card*", SUBSYSTEM=="drm", DRIVERS=="nvidia", RUN+="${pkgs.runtimeShell} -c 'mknod -m 666 /dev/nvidia%n c $(grep nvidia-frontend /proc/devices | cut -d \  -f 1) %n'"
        KERNEL=="nvidia_uvm", RUN+="${pkgs.runtimeShell} -c 'mknod -m 666 /dev/nvidia-uvm c $(grep nvidia-uvm /proc/devices | cut -d \  -f 1) 0'"
      '';

    boot.blacklistedKernelModules = [ "nouveau" "nvidiafb" ];

    services.acpid.enable = true;

  };

}
