{ config, pkgs, ... }:

{
  boot = {
    loader = {
      systemd-boot.enable = true;
      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot/efi";
      };
    };

    initrd = {
      supportedFilesystems = [ "nfs" ];
      kernelModules = [ "nfs" ];
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
