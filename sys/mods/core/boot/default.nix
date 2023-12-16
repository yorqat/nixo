{
  config,
  pkgs,
  lib,
  ...
}: 
let
  setup = import ../../../../setup;
  # Disabled when secure boot
  systemd-boot-enable = !setup.secureBoot.lanzaboote;
in {
  boot = {
    loader = {
      systemd-boot.enable = lib.mkForce systemd-boot-enable;
      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot";
      };
    };

    bootspec.enable = setup.secureBoot.bootspec;
    lanzaboote = {
      enable = setup.secureBoot.lanzaboote;
      pkiBundle = "/etc/secureboot";
    };

    initrd = {
      supportedFilesystems = ["nfs"];
      kernelModules = ["nfs"];
    };

    # Enable TTYs
    kernelParams = [
      "console=tty1"
      "console=tty2"
      "console=tty3"
      "console=tty4"
      "console=tty5"
      "console=tty6"
    ];
  };
}
