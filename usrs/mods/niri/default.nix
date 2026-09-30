{
  pkgs,
  lib,
  config,
  inputs,
  ...
}: let
  cfg = config.wayland.windowManager.niri;

  # home-manager's KDL generator writes `binds."Mod+Q".close-window = {}` as
  # `Mod+Q close-window` — a bare identifier as an *argument*, which KDL v2
  # rejects outright ("identifiers cannot be used as arguments"). niri reads an
  # action as a child node of the bind, so every action has to be wrapped in
  # `_children`. (home-manager's own niri module documents the broken form.)
  act = children: {
    _children = [children];
  };

  # niri has no `enable` knob: `border { off }` / `focus-ring { off }` turn the
  # decoration off and their absence turns it on, so "enabled" means "no `off`".
  # `on` is written explicitly because the border's own default is *off* — the
  # stylix block below is what turns it on, and that has to be visible in the
  # file rather than implied.
  workspaces = [
    "chat"
    "browse"
    "editor"
    "music"
    "video"
    "home"
  ];
in {
  home.packages = with pkgs; [
    libnotify
    wf-recorder
    brightnessctl
    # pamixer
    jq
    # slurp
    # tesseract5
    # grim
    wl-clipboard
    # pngquant
    # qt5.qtwayland

    imv
  ];

  services.mako.enable = true;

  programs.fuzzel = {
    enable = true;
    settings = {
      main = {
        terminal = "kitty";
        prompt = "'  '";
        width = 50; # in characters
        lines = 24;
        horizontal-pad = 24;
        vertical-pad = 16;
        inner-pad = 8; # gap between the prompt and the list
        line-height = 36;
        letter-spacing = 1;
      };
      border = {
        width = 4;
        radius = 8;
      };
    };
  };

  wayland.windowManager.niri = {
    enable = true;

    # xwayland-satellite (which niri uses to start XWayland) and niri's own
    # systemd units come from this module's defaults; pkgs.niri via
    # useGlobalPkgs, so this is the same binary programs.niri pins system-side.
    package = pkgs.niri;

    settings = {
      # Named workspaces always exist, even when empty. Dynamic (unnamed) ones
      # disappear when you leave them and `focus-workspace <idx>` only clamps to
      # the last existing workspace, which is why the bar's index buttons 3-6
      # could never switch anywhere. Address them by name instead.
      # Keys are sorted to fix on-screen order; `name` is what niri/bar/keybinds use.
      _children = map (name: {workspace._args = [name];}) workspaces;

      prefer-no-csd = true;

      screenshot-path = "~/Pictures/Screenshots/%Y-%m-%d_%H-%M-%S.png";

      layout.focus-ring = {
        on = {};
        active-gradient._props = {
          angle = 111;
          from = "rgba(70, 194, 171, 1)";
          to = "rgba(194, 204, 88, 1)";
          relative-to = "window";
        };
        inactive-gradient._props = {
          angle = 111;
          from = "rgba(93, 148, 138, 0.33)";
          to = "rgba(45, 68, 88, 1)";
          relative-to = "window";
        };
      };

      window-rule._children = [
        {
          clip-to-geometry = true;
          # top-left, top-right, bottom-right, bottom-left
          geometry-corner-radius = [
            4.0
            2.0
            4.0
            2.0
          ];
        }
      ];

      binds = {
        # screenshots
        "Print" = act {screenshot = {};};
        "Ctrl+Print" = act {screenshot-screen = {};};
        "Alt+Print" = act {screenshot-window = {};};

        # spawn now expects a list for multiple arguments
        "XF86AudioRaiseVolume" = act {
          spawn = [
            "sh"
            "-c"
            "wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1+ && eww open osc-volume --duration 2s"
          ];
        };
        "XF86AudioLowerVolume" = act {
          spawn = [
            "sh"
            "-c"
            "wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1- && eww open osc-volume --duration 2s"
          ];
        };
        "XF86MonBrightnessUp" = act {
          spawn = [
            "sh"
            "-c"
            "brightnessctl set +5% && eww open osc-brightness --duration 2s"
          ];
        };
        "XF86MonBrightnessDown" = act {
          spawn = [
            "sh"
            "-c"
            "brightnessctl set 5%- && eww open osc-brightness --duration 2s"
          ];
        };

        "Mod+Escape" = act {
          spawn = [
            "eww"
            "open"
            "--toggle"
            "powermenu"
          ];
        };

        "Mod+M" = act {power-off-monitors = {};};

        "Mod+D" = act {spawn-sh = "pkill -x fuzzel || fuzzel";};
        "Mod+0" = act {spawn = ["kitty"];};

        "Mod+Up" = act {focus-window-up = {};};
        "Mod+Down" = act {focus-window-down = {};};
        "Mod+Left" = act {focus-column-left = {};};
        "Mod+Right" = act {focus-column-right = {};};

        "Mod+K" = act {focus-window-up = {};};
        "Mod+J" = act {focus-window-down = {};};
        "Mod+H" = act {focus-column-left = {};};
        "Mod+L" = act {focus-column-right = {};};

        "Mod+BracketLeft" = act {consume-or-expel-window-left = {};};
        "Mod+BracketRight" = act {consume-or-expel-window-right = {};};

        "Mod+1" = act {focus-workspace = 1;};
        "Mod+2" = act {focus-workspace = 2;};
        "Mod+3" = act {focus-workspace = 3;};
        "Mod+4" = act {focus-workspace = 4;};
        "Mod+5" = act {focus-workspace = 5;};
        "Mod+6" = act {focus-workspace = 6;};
        "Mod+7" = act {focus-workspace = 7;};
        "Mod+8" = act {focus-workspace = 8;};
        "Mod+9" = act {focus-workspace = 9;};

        # Move the focused window to a named workspace (focus follows it).
        "Mod+Shift+1" = act {move-window-to-workspace = "chat";};
        "Mod+Shift+2" = act {move-window-to-workspace = "browse";};
        "Mod+Shift+3" = act {move-window-to-workspace = "editor";};
        "Mod+Shift+4" = act {move-window-to-workspace = "music";};
        "Mod+Shift+5" = act {move-window-to-workspace = "video";};
        "Mod+Shift+6" = act {move-window-to-workspace = "home";};

        # Rearrange windows inside the workspace.
        "Mod+Shift+H" = act {move-column-left = {};};
        "Mod+Shift+L" = act {move-column-right = {};};
        "Mod+Shift+J" = act {move-window-down = {};};
        "Mod+Shift+K" = act {move-window-up = {};};

        # Move the whole column to the previous/next workspace.
        "Mod+Shift+BracketLeft" = act {move-column-to-workspace-up = {};};
        "Mod+Shift+BracketRight" = act {move-column-to-workspace-down = {};};

        # Column layout: stacked <-> tabs.
        "Mod+T" = act {toggle-column-tabbed-display = {};};

        "Mod+F" = act {fullscreen-window = {};};
        "Mod+Q" = act {close-window = {};};

        "Mod+Shift+E" = act {quit = {};};

        # Nested flags for actions
        "Mod+Ctrl+Shift+E" = act {quit._props."skip-confirmation" = true;};

        "Mod+Shift+Slash" = act {show-hotkey-overlay = {};};

        "Mod+Plus" = act {set-column-width = "+10%";};
        "Mod+Minus" = act {set-column-width = "-10%";};
        "Mod+V" = act {toggle-window-floating = {};};
        "Mod+Shift+V" = act {switch-focus-between-floating-and-tiling = {};};
      };
    };
  };

  # stylix's HM integration has no niri target, so this is what niri-flake's
  # stylix target used to do. Kept in the same shape (niri reads the theme from
  # its own config, so these have to be in settings, not in the environment).
  wayland.windowManager.niri.settings = {
    cursor = {
      xcursor-theme = config.stylix.cursor.name;
      xcursor-size = config.stylix.cursor.size;
    };
    layout.border = with config.lib.stylix.colors.withHashtag; {
      on = {};
      active-color = base0D;
      inactive-color = base03;
    };
  };

  # niri has no polkit agent of its own and nixpkgs does not start one, but
  # blueman/NetworkManager/power-profiles-daemon all have polkit actions that
  # then have no way to prompt. security.polkit.enable comes from nixpkgs'
  # programs.niri (via wayland-session.nix); this is just the agent.
  systemd.user.services.polkit-gnome-authentication-agent = {
    Unit.Description = "PolicyKit Authentication Agent";
    Unit.After = ["graphical-session.target"];
    Unit.PartOf = ["graphical-session.target"];
    Install.WantedBy = ["graphical-session.target"];
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
      Restart = "on-failure";
      RestartSec = 1;
      TimeoutStopSec = 10;
    };
  };

  # Wallpaper as a managed service (was: fire-and-forget `swaybg` in
  # spawn-at-startup, which never restarted with niri and couldn't follow the
  # theme). It reads a stable symlink that scripts/theme flips dark<->light;
  # tmpfiles re-points it at the dark image on every session start, so a reboot
  # always lands on the base theme consistently.
  systemd.user.tmpfiles.rules = [
    "L+ ${config.home.homeDirectory}/.config/niri/wallpaper.png - - - - ${config.home.homeDirectory}/.config/eww/images/wallpapers/stitch_wall_dark.png"
  ];

  programs.swaylock.enable = true;
  services.swayidle = {
    enable = true;
    timeouts = [
      {
        timeout = 300;
        command = "${lib.getExe pkgs.swaylock} -f";
      }
      {
        timeout = 600;
        command = "niri msg action power-off-monitors";
      }
    ];
  };

  systemd.user.services.swaybg = {
    Unit = {
      Description = "Wallpaper (swaybg)";
      PartOf = ["niri.service"];
      After = ["niri.service"];
    };
    Service = {
      ExecStart = "${lib.getExe pkgs.swaybg} --image ${config.home.homeDirectory}/.config/niri/wallpaper.png --mode fill --output *";
      Restart = "on-failure";
    };
    Install.WantedBy = ["niri.service"];
  };
}
