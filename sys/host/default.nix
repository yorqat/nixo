{
  pkgs,
  lib,
  config,
  setup,
  ...
}: let
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

  zramSwap.enable = true;

  users.mutableUsers = false;
  users.users."${setup.userName}" = {
    isNormalUser = true;
    description = "${setup.userName} (very cool person)";
    extraGroups = ["networkmanager" "wheel" "audio" "video" "input" "kvm" "libvirtd" "docker"];

    hashedPasswordFile = config.sops.secrets."yor-password-hash".path;
  };

  programs.ente-auth.enable = true;

  programs.xwayland.enable = true;

  programs.nautilus-open-any-terminal = {
    enable = true;
  };

  programs.niri = {
    enable = true;
  };

  # The system chromium module also emits managed policies for Brave
  # (/etc/brave/policies/managed/*.json), so this drives Brave's defaults.
  # (Home-manager has no Brave module, hence system-level.)
  programs.chromium = {
    enable = true;
    defaultSearchProviderEnabled = true;
    defaultSearchProviderSearchURL = "https://www.google.com/search?q={searchTerms}";
    defaultSearchProviderSuggestURL = "https://www.google.com/complete/search?output=chrome&q={searchTerms}";

    # Basic, non-intrusive hardening. Google search is kept on purpose (dev
    # tooling); Brave's own Shields + Safe Browsing stay on as the real defense.
    extraOpts = {
      MetricsReportingEnabled = false;
      PersonalizationReportingEnabled = false;
      BrowserSignin = 0;
      SyncDisabled = true;
      DNSOverHttpsMode = "automatic";
    };
  };

  programs.firefox = {
    enable = true;
    package = pkgs.firefox-devedition;

    # Basic privacy only, and left user-overridable ("default", not "locked")
    # so about:config stays usable while developing. No RFP / arkenfox: those
    # break local dev, logins and devtools.
    preferencesStatus = "default";
    preferences = {
      "datareporting.healthreport.uploadEnabled" = false;
      "datareporting.policy.dataSubmissionEnabled" = false;
      "app.shield.optoutstudies.enabled" = false;
      "app.normandy.enabled" = false;
      "browser.urlbar.suggest.quicksuggest.sponsored" = false;
      "browser.urlbar.suggest.quicksuggest.nonsponsored" = false;
      "network.trr.mode" = 3; # DoH automatic (non-intrusive)
      "privacy.trackingprotection.enabled" = true;
    };

    policies = {
      ExtensionSettings = {
        # The key MUST match the extension's internal ID
        "uBlock0@raymondhill.net" = {
          # normal_installed (not force) so the blocker can be toggled off
          # while developing against a site that needs the blocked origin.
          installation_mode = "normal_installed";
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
        };
      };
    };
  };

  # services.desktopManager.plasma6.enable = setup.includes.plasma6;
  services.desktopManager.plasma6.enable = false;

  # for virt-manager
  virtualisation.libvirtd = {
    enable = setup.includes.virt-manager;
  };

  programs.dconf.enable = true;
  hardware.graphics.enable = true;
  # For steam
  hardware.steam-hardware.enable = setup.includes.steam;
  programs.steam.enable = setup.includes.steam;

  services = {
    # dbus.enable = true;
    # enable powerprofilesctl
    power-profiles-daemon.enable = true;

    resolved.enable = true;

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
    openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        PermitRootLogin = "no";
      };
    };
  };

  # Pin the current Home Manager generation to a stable, GC-rooted path (a symlink
  # in /etc keeps the base generation alive) so the eww dark/light toggle can run
  # its `activate` scripts. Done at the system level because referencing the
  # generation from inside the HM config recurses.
  environment.etc."current-home-generation".source =
    config.home-manager.users."${setup.userName}".home.activationPackage;

  environment.systemPackages = with pkgs;
    [
      # adwaita-icon-theme
      ifuse
      nfs-utils
    ]
    ++ includeVirtManager;
}
