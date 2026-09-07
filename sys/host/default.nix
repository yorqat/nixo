{
  pkgs,
  lib,
  ...
}: let
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
  services.ollama.enable = true;

  users.users."${setup.userName}" = {
    isNormalUser = true;
    description = "${setup.userName} (very cool person)";
    extraGroups = ["networkmanager" "wheel" "audio" "video" "input" "kvm" "libvirtd" "docker"];
    packages = with pkgs; [];
  };

  programs.ente-auth.enable = true;

  programs.xwayland.enable = true;

  programs.niri = {
    enable = true;
  };

  # ungoogled-chromium strips Google from the built-in search engine list;
  # restore it via a managed policy (the home-manager chromium module has
  # no policy support, so this must live at the system level).
  programs.chromium = {
    enable = true;
    defaultSearchProviderEnabled = true;
    defaultSearchProviderSearchURL = "https://www.google.com/search?q={searchTerms}";
    defaultSearchProviderSuggestURL = "https://www.google.com/complete/search?output=chrome&q={searchTerms}";
  };

  programs.firefox = {
    enable = true;
    package = pkgs.firefox-devedition;
    policies = {
      ExtensionSettings = {
        # The key MUST match the extension's internal ID
        "adnauseam@rednoise.org" = {
          installation_mode = "force_installed";
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/adnauseam/latest.xpi";
        };
      };
    };
  };

  services.desktopManager.plasma6.enable = true;

  # for virt-manager
  virtualisation.libvirtd = {
    enable = setup.includes.virt-manager;
    # qemu.ovmf.packages = [ pkgs.OVMFFull.fd pkgs.pkgsCross.aarch64-multiplatform.OVMF.fd ];
  };

  # virtualisation.docker.enable = setup.includes.docker;
  programs.dconf.enable = true;
  # For steam
  hardware.steam-hardware.enable = setup.includes.steam;
  programs.steam.enable = setup.includes.steam;

  services = {
    # dbus.enable = true;
    # enable powerprofilesctl
    power-profiles-daemon.enable = true;

    xserver = {
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
    avahi.nssmdns6 = true;
    # flatpak.enable = true;
    openssh.enable = true;
  };

  environment.systemPackages = with pkgs;
    [
      adwaita-icon-theme
      ifuse
      nfs-utils
    ]
    ++ includeVirtManager;
}
