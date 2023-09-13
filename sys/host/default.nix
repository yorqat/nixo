{pkgs, ...}: {
  time.timeZone = "Asia/Manila";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_PH.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "fil_PH";
    LC_IDENTIFICATION = "fil_PH";
    LC_MEASUREMENT = "fil_PH";
    LC_MONETARY = "fil_PH";
    LC_NAME = "fil_PH";
    LC_NUMERIC = "fil_PH";
    LC_PAPER = "fil_PH";
    LC_TELEPHONE = "fil_PH";
    LC_TIME = "fil_PH";
  };

  networking.hostName = "qat";
  services.getty.autologinUser = "yor";

  users.users.yor = {
    isNormalUser = true;
    description = "yor";
    extraGroups = ["networkmanager" "wheel" "audio" "video" "input" "kvm" "libvirtd" "docker"];
    packages = with pkgs; [];
  };

  programs.xwayland.enable = true;
  # for virt-manager
  virtualisation.libvirtd = {
    enable = true;
    # qemu.ovmf.packages = [ pkgs.OVMFFull.fd pkgs.pkgsCross.aarch64-multiplatform.OVMF.fd ];
  };
  virtualisation.docker.enable = true;
  programs.dconf.enable = true;
  hardware.opengl.enable = true;
  # For steam
  hardware.steam-hardware.enable = true;
  programs.steam.enable = true;

  services = {
    xserver = {
      layout = "us";
      xkbVariant = "";
    };

    #plex = {
    #enable = true;
    #openFirewall = true;
    #};

    gnome = {
      glib-networking.enable = true;
      gnome-keyring.enable = true;
    };

    udev.packages = with pkgs; [gnome.gnome-settings-daemon];

    usbmuxd.enable = true;
    avahi.enable = true;
    avahi.nssmdns = true;
    flatpak.enable = true;
    openssh.enable = true;
  };

  environment.systemPackages = with pkgs; [
    lua
    libimobiledevice
    gnome.adwaita-icon-theme
    neofetch

    imagemagick
    ffmpeg_6-full

    ifuse
    virt-manager

    # nfs support
    nfs-utils

    wget
  ];

  environment.variables.EDITOR = "nvim";
}
