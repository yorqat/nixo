{
  config,
  pkgs,
  lib,
  ...
}: {
  boot = {
    loader = {
      # force disable systemd-boot for lanzaboote
      systemd-boot.enable = lib.mkForce false;
      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot";
      };
    };

    # secure boot requirement
    bootspec.enable = true;
    lanzaboote = {
      enable = true;
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
