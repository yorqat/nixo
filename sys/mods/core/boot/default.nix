{
  config,
  pkgs,
  lib,
  setup,
  ...
}: let
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
