{ pkgs, lib, ... }: let
  setup = import ../../setup;

  includeVirtManager = lib.optional setup.includes.virt-manager pkgs.virt-manager;
in {
  time.timeZone = "${setup.timeZone}";

  # Select internationalisation properties.
  i18n.defaultLocale = "${setup.defaultLocale}";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "${setup.extraLocale}";
    LC_IDENTIFICATION = "${setup.extraLocale}";
    LC_MEASUREMENT = "${setup.extraLocale}";
    LC_MONETARY = "${setup.extraLocale}";
    LC_NAME = "${setup.extraLocale}";
    LC_NUMERIC = "${setup.extraLocale}";
    LC_PAPER = "${setup.extraLocale}";
    LC_TELEPHONE = "${setup.extraLocale}";
    LC_TIME = "${setup.extraLocale}";
  };

  networking.hostName = "${setup.hostName}";
  services.getty.autologinUser = "${setup.userName}";

  users.users."${setup.userName}" = {
    isNormalUser = true;
    description = "${setup.userName} (very cool person)";
    extraGroups = ["networkmanager" "wheel" "audio" "video" "input" "kvm" "libvirtd" "docker"];
    packages = with pkgs; [];
  };

  programs.xwayland.enable = true;

  programs.niri = {
    enable = true;
  };

  services.xserver.desktopManager.gnome.enable = true;

  programs.zoxide = {
    enable = true;
    enableBashIntegration = true;
  };

  # for virt-manager
  virtualisation.libvirtd = {
    enable = setup.includes.virt-manager;
    # qemu.ovmf.packages = [ pkgs.OVMFFull.fd pkgs.pkgsCross.aarch64-multiplatform.OVMF.fd ];
  };

  # virtualisation.docker.enable = setup.includes.docker;
  programs.dconf.enable = true;
  hardware.graphics.enable = true;
  # For steam
  hardware.steam-hardware.enable = setup.includes.steam;
  programs.steam.enable = setup.includes.steam;

  services = {
    dbus.enable = true;
    # enable powerprofilesctl
    power-profiles-daemon.enable = true;

    xserver = 
    {
      enable = true;

      xkb = {
        layout = "us";
        variant = "";
      };
    };

    displayManager.sddm.enable = true;

    gnome = {
      glib-networking.enable = true;
      gnome-keyring.enable = true;
    };

    udev.packages = with pkgs; [gnome-settings-daemon];

    usbmuxd.enable = true;
    avahi.enable = true;
    avahi.nssmdns4 = true;
    # flatpak.enable = true;
    openssh.enable = true;
  };

  environment.systemPackages = with pkgs; [
    lua
    libimobiledevice
    adwaita-icon-theme
    neofetch

    imagemagick
    ffmpeg_6-full

    ifuse
    
    # nfs support
    nfs-utils

    wget
  ] ++ includeVirtManager;

  environment.variables.EDITOR = "nvim";
}
