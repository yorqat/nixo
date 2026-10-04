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

    # TEMP: so i can build for these targets
    binfmt.emulatedSystems = ["aarch64-linux"];
  };

  # Make /boot (vfat ESP) not world-readable; matches systemd-boot warning
  fileSystems."/boot".options = lib.mkForce ["fmask=0077" "dmask=0077"];

  # Text-mode fallback if niri/sddm fail. Log in on tty2..tty6 with Ctrl+Alt+F*.
  # These are wanted at boot rather than spawned by logind's autovt@ on VT
  # switch, so a login prompt exists even if logind is the thing that broke.
  # tty1 is left to sddm's greeter.
  systemd.services =
    lib.genAttrs (
      map (vt: "getty@${vt}") ["tty2" "tty3" "tty4" "tty5" "tty6"]
    ) (_: {
      wantedBy = ["multi-user.target"];
    });
}
