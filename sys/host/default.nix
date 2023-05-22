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

  networking.hostName = "qaten";
  services.getty.autologinUser = "yoru";

  users.users.yoru = {
    isNormalUser = true;
    description = "Yoru";
    extraGroups = ["networkmanager" "wheel" "video" "input" "kvm" "libvirt" "docker"];
    packages = with pkgs; [
      # Editor
      firefox-wayland
      # eww-wayland

      wofi

      # Audio
      pavucontrol
      helvum

      # Screenshot
      slurp
      grim

      # Notifications
      mako
      libnotify

      # Clipboard
      wl-clipboard
    ];
  };

  programs.xwayland.enable = true;
  programs.dconf.enable = true;
  hardware.opengl.enable = true;

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
    docker-client

    # nfs support
    nfs-utils
  ];

  environment.variables.EDITOR = "nvim";
}
