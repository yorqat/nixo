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

  # Like `act`, but also emits bind-level KDL properties: `hotkey-overlay-title`,
  # `allow-when-locked`, `allow-inhibiting`, `repeat`, `cooldown-ms`, ...
  bind = props: children: {
    _props = props;
    _children = [children];
  };

  # Every bind carries a hotkey-overlay-title so Mod+Shift+Slash (and the
  # startup pop-up) list *our* scheme. Without it the overlay only shows niri's
  # built-in defaults — which this config overrides — plus untitled spawn binds,
  # i.e. it would actively teach the wrong keys. `title` is the common case.
  title = t: children: bind {"hotkey-overlay-title" = t;} children;

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

      # The overlay's built-in list includes niri defaults this config
      # overrides, so hide anything we haven't bound; what's left (the titled
      # binds below) is a true cheat-sheet.
      hotkey-overlay.hide-not-bound = {};

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
        "Print" = title "Screenshot: choose a region" {screenshot = {};};
        "Ctrl+Print" = title "Screenshot: whole screen" {screenshot-screen = {};};
        "Alt+Print" = title "Screenshot: focused window" {screenshot-window = {};};

        # media keys — allow-when-locked so they keep working on the lockscreen
        "XF86AudioRaiseVolume" =
          bind {
            "allow-when-locked" = true;
            "hotkey-overlay-title" = "Volume up";
          } {
            spawn-sh = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1+ -l 1.0 && eww open osc-volume --duration 2s";
          };
        "XF86AudioLowerVolume" =
          bind {
            "allow-when-locked" = true;
            "hotkey-overlay-title" = "Volume down";
          } {
            spawn-sh = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1- && eww open osc-volume --duration 2s";
          };
        "XF86AudioMute" =
          bind {
            "allow-when-locked" = true;
            "hotkey-overlay-title" = "Mute";
          } {
            spawn-sh = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle && eww open osc-volume --duration 2s";
          };
        "XF86AudioMicMute" =
          bind {
            "allow-when-locked" = true;
            "hotkey-overlay-title" = "Mute microphone";
          } {
            spawn-sh = "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle";
          };

        # transport, driven by mpd like the eww music widget
        "XF86AudioPlay" =
          bind {
            "allow-when-locked" = true;
            "hotkey-overlay-title" = "Play / pause";
          } {
            spawn-sh = "mpc toggle";
          };
        "XF86AudioStop" =
          bind {
            "allow-when-locked" = true;
            "hotkey-overlay-title" = "Stop";
          } {
            spawn-sh = "mpc stop";
          };
        "XF86AudioPrev" =
          bind {
            "allow-when-locked" = true;
            "hotkey-overlay-title" = "Previous track";
          } {
            spawn-sh = "mpc prev";
          };
        "XF86AudioNext" =
          bind {
            "allow-when-locked" = true;
            "hotkey-overlay-title" = "Next track";
          } {
            spawn-sh = "mpc next";
          };

        "XF86MonBrightnessUp" =
          bind {
            "allow-when-locked" = true;
            "hotkey-overlay-title" = "Brightness up";
          } {
            spawn-sh = "brightnessctl set +5% && eww open osc-brightness --duration 2s";
          };
        "XF86MonBrightnessDown" =
          bind {
            "allow-when-locked" = true;
            "hotkey-overlay-title" = "Brightness down";
          } {
            spawn-sh = "brightnessctl set 5%- && eww open osc-brightness --duration 2s";
          };

        # session
        "Super+Alt+L" =
          bind {
            "allow-inhibiting" = false;
            "hotkey-overlay-title" = "Lock the screen";
          } {
            spawn = [(lib.getExe pkgs.swaylock)];
          };
        "Mod+Shift+Escape" = title "Power menu" {
          spawn = ["eww" "open" "--toggle" "powermenu"];
        };
        "Mod+Shift+P" = title "Turn off monitors" {power-off-monitors = {};};

        # launcher / terminal
        "Mod+D" = title "App launcher: fuzzel" {
          spawn-sh = "pkill -x fuzzel || fuzzel";
        };
        "Mod+T" = title "Terminal: kitty" {spawn = ["kitty"];};
        "Mod+Return" = title "Terminal: kitty" {spawn = ["kitty"];};
        "Mod+0" = act {spawn = ["kitty"];};

        "Mod+O" =
          bind {
            repeat = false;
            "hotkey-overlay-title" = "Overview";
          } {
            toggle-overview = {};
          };

        # focus
        "Mod+Up" = title "Focus window up" {focus-window-up = {};};
        "Mod+Down" = title "Focus window down" {focus-window-down = {};};
        "Mod+Left" = title "Focus column left" {focus-column-left = {};};
        "Mod+Right" = title "Focus column right" {focus-column-right = {};};
        "Mod+K" = title "Focus window up" {focus-window-up = {};};
        "Mod+J" = title "Focus window down" {focus-window-down = {};};
        "Mod+H" = title "Focus column left" {focus-column-left = {};};
        "Mod+L" = title "Focus column right" {focus-column-right = {};};
        "Mod+Home" = title "Focus first column" {focus-column-first = {};};
        "Mod+End" = title "Focus last column" {focus-column-last = {};};

        # move the focused window / column
        "Mod+Ctrl+Up" = title "Move window up" {move-window-up = {};};
        "Mod+Ctrl+Down" = title "Move window down" {move-window-down = {};};
        "Mod+Ctrl+Left" = title "Move column left" {move-column-left = {};};
        "Mod+Ctrl+Right" = title "Move column right" {move-column-right = {};};
        "Mod+Ctrl+K" = title "Move window up" {move-window-up = {};};
        "Mod+Ctrl+J" = title "Move window down" {move-window-down = {};};
        "Mod+Ctrl+H" = title "Move column left" {move-column-left = {};};
        "Mod+Ctrl+L" = title "Move column right" {move-column-right = {};};
        "Mod+Ctrl+Home" = title "Move column to first" {move-column-to-first = {};};
        "Mod+Ctrl+End" = title "Move column to last" {move-column-to-last = {};};

        # monitors
        "Mod+Shift+Up" = title "Focus monitor up" {focus-monitor-up = {};};
        "Mod+Shift+Down" = title "Focus monitor down" {focus-monitor-down = {};};
        "Mod+Shift+Left" = title "Focus monitor left" {focus-monitor-left = {};};
        "Mod+Shift+Right" = title "Focus monitor right" {focus-monitor-right = {};};
        "Mod+Shift+K" = title "Focus monitor up" {focus-monitor-up = {};};
        "Mod+Shift+J" = title "Focus monitor down" {focus-monitor-down = {};};
        "Mod+Shift+H" = title "Focus monitor left" {focus-monitor-left = {};};
        "Mod+Shift+L" = title "Focus monitor right" {focus-monitor-right = {};};
        "Mod+Shift+Ctrl+Up" = title "Move column to monitor up" {move-column-to-monitor-up = {};};
        "Mod+Shift+Ctrl+Down" = title "Move column to monitor down" {move-column-to-monitor-down = {};};
        "Mod+Shift+Ctrl+Left" = title "Move column to monitor left" {move-column-to-monitor-left = {};};
        "Mod+Shift+Ctrl+Right" = title "Move column to monitor right" {move-column-to-monitor-right = {};};
        "Mod+Shift+Ctrl+K" = title "Move column to monitor up" {move-column-to-monitor-up = {};};
        "Mod+Shift+Ctrl+J" = title "Move column to monitor down" {move-column-to-monitor-down = {};};
        "Mod+Shift+Ctrl+H" = title "Move column to monitor left" {move-column-to-monitor-left = {};};
        "Mod+Shift+Ctrl+L" = title "Move column to monitor right" {move-column-to-monitor-right = {};};

        # workspaces: jump by name (numeric indices clamp against a fixed set)
        "Mod+1" = title "Workspace: chat" {focus-workspace = "chat";};
        "Mod+2" = title "Workspace: browse" {focus-workspace = "browse";};
        "Mod+3" = title "Workspace: editor" {focus-workspace = "editor";};
        "Mod+4" = title "Workspace: music" {focus-workspace = "music";};
        "Mod+5" = title "Workspace: video" {focus-workspace = "video";};
        "Mod+6" = title "Workspace: home" {focus-workspace = "home";};

        # move a window to a named workspace (focus follows it)
        "Mod+Shift+1" = title "Send window to: chat" {move-window-to-workspace = "chat";};
        "Mod+Shift+2" = title "Send window to: browse" {move-window-to-workspace = "browse";};
        "Mod+Shift+3" = title "Send window to: editor" {move-window-to-workspace = "editor";};
        "Mod+Shift+4" = title "Send window to: music" {move-window-to-workspace = "music";};
        "Mod+Shift+5" = title "Send window to: video" {move-window-to-workspace = "video";};
        "Mod+Shift+6" = title "Send window to: home" {move-window-to-workspace = "home";};

        # move a whole column to a named workspace
        "Mod+Ctrl+1" = title "Send column to: chat" {move-column-to-workspace = "chat";};
        "Mod+Ctrl+2" = title "Send column to: browse" {move-column-to-workspace = "browse";};
        "Mod+Ctrl+3" = title "Send column to: editor" {move-column-to-workspace = "editor";};
        "Mod+Ctrl+4" = title "Send column to: music" {move-column-to-workspace = "music";};
        "Mod+Ctrl+5" = title "Send column to: video" {move-column-to-workspace = "video";};
        "Mod+Ctrl+6" = title "Send column to: home" {move-column-to-workspace = "home";};

        # step through workspaces without knowing their number
        "Mod+Page_Down" = title "Workspace down" {focus-workspace-down = {};};
        "Mod+Page_Up" = title "Workspace up" {focus-workspace-up = {};};
        "Mod+U" = title "Workspace down" {focus-workspace-down = {};};
        "Mod+I" = title "Workspace up" {focus-workspace-up = {};};
        "Mod+Tab" = title "Previous workspace" {focus-workspace-previous = {};};
        "Mod+Ctrl+Page_Down" = title "Move column down a workspace" {move-column-to-workspace-down = {};};
        "Mod+Ctrl+Page_Up" = title "Move column up a workspace" {move-column-to-workspace-up = {};};
        "Mod+Ctrl+U" = title "Move column down a workspace" {move-column-to-workspace-down = {};};
        "Mod+Ctrl+I" = title "Move column up a workspace" {move-column-to-workspace-up = {};};
        "Mod+Shift+Page_Down" = title "Move workspace down" {move-workspace-down = {};};
        "Mod+Shift+Page_Up" = title "Move workspace up" {move-workspace-up = {};};
        "Mod+Shift+U" = title "Move workspace down" {move-workspace-down = {};};
        "Mod+Shift+I" = title "Move workspace up" {move-workspace-up = {};};

        # consume/expel windows and columns
        "Mod+BracketLeft" = title "Consume/expel window left" {consume-or-expel-window-left = {};};
        "Mod+BracketRight" = title "Consume/expel window right" {consume-or-expel-window-right = {};};
        "Mod+Comma" = title "Consume window into column" {consume-window-into-column = {};};
        "Mod+Period" = title "Expel window from column" {expel-window-from-column = {};};

        # column geometry
        "Mod+R" = title "Cycle column width" {switch-preset-column-width = {};};
        "Mod+Shift+R" = title "Cycle column width (reverse)" {switch-preset-column-width-back = {};};
        "Mod+Ctrl+Shift+R" = title "Cycle window height" {switch-preset-window-height = {};};
        "Mod+Ctrl+R" = title "Reset window height" {reset-window-height = {};};
        "Mod+F" = title "Maximize column" {maximize-column = {};};
        "Mod+Shift+F" = title "Fullscreen window" {fullscreen-window = {};};
        "Mod+M" = title "Maximize window to edges" {maximize-window-to-edges = {};};
        "Mod+Ctrl+F" = title "Expand column to fill" {expand-column-to-available-width = {};};
        "Mod+C" = title "Center column" {center-column = {};};
        "Mod+Ctrl+C" = title "Center visible columns" {center-visible-columns = {};};
        "Mod+Minus" = title "Narrow column" {set-column-width = "-10%";};
        "Mod+Equal" = title "Widen column" {set-column-width = "+10%";};
        "Mod+Shift+Minus" = title "Shorten window" {set-window-height = "-10%";};
        "Mod+Shift+Equal" = title "Enlarge window" {set-window-height = "+10%";};

        # layout
        "Mod+W" = title "Toggle tabbed column" {toggle-column-tabbed-display = {};};
        "Mod+V" = title "Toggle floating" {toggle-window-floating = {};};
        "Mod+Shift+V" = title "Swap floating/tiling focus" {switch-focus-between-floating-and-tiling = {};};

        # windows and session
        "Mod+Q" = title "Close window" {close-window = {};};
        "Mod+Shift+E" = title "Quit niri" {quit = {};};
        "Mod+Ctrl+Shift+E" = act {quit._props."skip-confirmation" = true;};
        "Mod+Escape" =
          bind {
            "allow-inhibiting" = false;
            "hotkey-overlay-title" = "Toggle keyboard-shortcuts inhibit";
          } {
            toggle-keyboard-shortcuts-inhibit = {};
          };
        "Mod+Shift+Slash" = title "This help" {show-hotkey-overlay = {};};

        # mouse wheel
        "Mod+WheelScrollDown" = bind {"cooldown-ms" = 150;} {focus-workspace-down = {};};
        "Mod+WheelScrollUp" = bind {"cooldown-ms" = 150;} {focus-workspace-up = {};};
        "Mod+Ctrl+WheelScrollDown" = bind {"cooldown-ms" = 150;} {move-column-to-workspace-down = {};};
        "Mod+Ctrl+WheelScrollUp" = bind {"cooldown-ms" = 150;} {move-column-to-workspace-up = {};};
        "Mod+WheelScrollRight" = act {focus-column-right = {};};
        "Mod+WheelScrollLeft" = act {focus-column-left = {};};
        "Mod+Ctrl+WheelScrollRight" = act {move-column-right = {};};
        "Mod+Ctrl+WheelScrollLeft" = act {move-column-left = {};};
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
