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

  # nixpkgs' module (auto-imported): it brings the sddm session file, niri's
  # systemd units, the gnome portal, polkit and the swaylock pam service.
  # The session's own settings live in usrs/mods/niri, under
  # wayland.windowManager.niri.
  programs.niri = {
    enable = true;
    package = pkgs.niri;
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

    # Wayland-only box, no X server: X apps go through programs.xwayland
    # (xwayland-satellite) and the greeter through sddm's own wayland mode.
    # Those two are one change, not two options to pick between — sddm.nix
    # asserts `xcfg.enable || cfg.wayland.enable`, so dropping the X server
    # without the wayland greeter does not even evaluate.
    # The greeter is not a maybe: weston 16.0.0 --shell=kiosk (drm-backend,
    # gl-renderer) booted a working login screen on this GPU on 2026-09-30.
    xserver = {
      enable = false;

      # Load-bearing without the X server, with two live consumers, neither of
      # which is /etc/X11/xkb — that is gated on
      # services.xserver.exportConfiguration, which is false (AUDIT.md 4.14):
      #
      #   - services.displayManager.sddm.wayland generates weston.ini with a
      #     [keyboard] section from xcfg.xkb.* (sddm.nix:135-142), and that is
      #     the greeter's actual keymap. Not gated on xserver.enable.
      #   - services.graphical-desktop renders
      #     /etc/X11/xorg.conf.d/00-keyboard.conf from xcfg.xkb.*
      #     (graphical-desktop.nix:27), systemd-localed parses it and
      #     republishes it on org.freedesktop.locale1, and niri reads it from
      #     there because its own `xkb {}` block is empty — niri's docs: "If
      #     the xkb section is empty ... niri will fetch xkb settings from
      #     systemd-localed" (since 25.08).
      #
      # Stated rather than inherited: nothing else in the tree names a layout,
      # and if both consumers ever stopped finding it, niri would silently fall
      # back to libxkbcommon's built-in default (layout "English (US)", no
      # model, no options) with nothing in the logs.
      #
      # Only layout is pinned. model ("pc104") and options
      # ("terminate:ctrl_alt_bksp") stay on the nixpkgs defaults, which is what
      # weston.ini and localectl report today; terminate:ctrl_alt_bksp kills
      # the *X server*, which this box does not run, so pinning it would
      # enshrine an inert X-ism. The TTY keymap is a separate option and does
      # not read this (console.useXkbConfig = false).
      xkb.layout = "us";
    };

    displayManager = {
      sddm.enable = true;
      sddm.wayland.enable = true;
    };

    usbmuxd.enable = true;

    avahi.enable = true;
    # Both, not just 6: nixpkgs picks the nss database name from these two
    # (avahi-daemon.nix:334-339), so nssmdns6 alone yields `mdns6_minimal`,
    # which answers AAAA only. `ssh qat.local` resolves AF_UNSPEC, tries A
    # first, gets NOTFOUND, and `[NOTFOUND=return]` ends the chain before
    # `resolve` -- so .local worked in getent but not in ssh or ping. Both set
    # gives `mdns_minimal`, which handles A and AAAA.
    avahi.nssmdns4 = true;
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

  # Pin the current Home Manager generation to a stable, GC-rooted path
  # (the system closure roots it; /etc symlink is just the stable path)
  # so the eww dark/light toggle can run its `activate` scripts.
  # Done at the system level because referencing the generation from inside
  # the HM config recurses (see AUDIT.md 3.9).
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
