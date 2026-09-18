{
  pkgs,
  lib,
  config,
  inputs,
  ...
}: {
  home.packages = with pkgs; [
    libnotify
    wf-recorder
    brightnessctl
    pamixer
    jq
    slurp
    tesseract5
    grim
    wl-clipboard
    pngquant
    qt5.qtwayland

    xwayland-satellite

    wofi
    mako
    swaybg
    imv
  ];

  programs.niri.settings = {
    # Named workspaces always exist, even when empty. Dynamic (unnamed) ones
    # disappear when you leave them and `focus-workspace <idx>` only clamps to
    # the last existing workspace, which is why the bar's index buttons 3-6
    # could never switch anywhere. Address them by name instead.
    # Keys are sorted to fix on-screen order; `name` is what niri/bar/keybinds use.
    workspaces = {
      "01" = {name = "chat";};
      "02" = {name = "browse";};
      "03" = {name = "editor";};
      "04" = {name = "music";};
      "05" = {name = "video";};
      "06" = {name = "home";};
    };

    prefer-no-csd = true;

    layout = {
      focus-ring = {
        enable = true;

        active = {
          gradient = {
            angle = 111;
            from = "rgba(70, 194, 171, 1)";
            to = "rgba(194, 204, 88, 1)";
            relative-to = "window";
          };
        };

        inactive = {
          gradient = {
            angle = 111;
            from = "rgba(93, 148, 138, 0.33)";
            to = "rgba(45, 68, 88, 1)";
            relative-to = "window";
          };
        };
      };
    };

    window-rules = [
      {
        clip-to-geometry = true;
        geometry-corner-radius = {
          top-left = 16.0;
          top-right = 16.0;
          bottom-left = 16.0;
          bottom-right = 16.0;
        };
      }
    ];

    binds = {
      # spawn now expects a list for multiple arguments
      "XF86AudioRaiseVolume".action.spawn = ["sh" "-c" "wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1+ && eww open osc-volume --duration 2s"];
      "XF86AudioLowerVolume".action.spawn = ["sh" "-c" "wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1- && eww open osc-volume --duration 2s"];
      "XF86MonBrightnessUp".action.spawn = ["sh" "-c" "brightnessctl set +5% && eww open osc-brightness --duration 2s"];
      "XF86MonBrightnessDown".action.spawn = ["sh" "-c" "brightnessctl set 5%- && eww open osc-brightness --duration 2s"];

      "Mod+Escape".action.spawn = ["eww" "open" "--toggle" "powermenu"];

      # Actions with no arguments MUST be empty sets
      "Mod+M".action.power-off-monitors = {};

      "Mod+D".action.spawn = ["wofi" "--show" "drun" "--columns" "3" "--gtk-dark" "--allow-images" "--fork"];
      "Mod+0".action.spawn = ["kitty"];

      "Mod+Up".action.focus-window-up = {};
      "Mod+Down".action.focus-window-down = {};
      "Mod+Left".action.focus-column-left = {};
      "Mod+Right".action.focus-column-right = {};

      "Mod+K".action.focus-window-up = {};
      "Mod+J".action.focus-window-down = {};
      "Mod+H".action.focus-column-left = {};
      "Mod+L".action.focus-column-right = {};

      "Mod+BracketLeft".action.consume-or-expel-window-left = {};
      "Mod+BracketRight".action.consume-or-expel-window-right = {};

      "Mod+1".action.focus-workspace = 1;
      "Mod+2".action.focus-workspace = 2;
      "Mod+3".action.focus-workspace = 3;
      "Mod+4".action.focus-workspace = 4;
      "Mod+5".action.focus-workspace = 5;
      "Mod+6".action.focus-workspace = 6;
      "Mod+7".action.focus-workspace = 7;
      "Mod+8".action.focus-workspace = 8;
      "Mod+9".action.focus-workspace = 9;

      # Move the focused window to a named workspace (focus follows it).
      "Mod+Shift+1".action.move-window-to-workspace = "chat";
      "Mod+Shift+2".action.move-window-to-workspace = "browse";
      "Mod+Shift+3".action.move-window-to-workspace = "editor";
      "Mod+Shift+4".action.move-window-to-workspace = "music";
      "Mod+Shift+5".action.move-window-to-workspace = "video";
      "Mod+Shift+6".action.move-window-to-workspace = "home";

      # Rearrange windows inside the workspace.
      "Mod+Shift+H".action.move-column-left = {};
      "Mod+Shift+L".action.move-column-right = {};
      "Mod+Shift+J".action.move-window-down = {};
      "Mod+Shift+K".action.move-window-up = {};

      # Move the whole column to the previous/next workspace.
      "Mod+Shift+BracketLeft".action.move-column-to-workspace-up = {};
      "Mod+Shift+BracketRight".action.move-column-to-workspace-down = {};

      # Column layout: stacked <-> tabs.
      "Mod+T".action.toggle-column-tabbed-display = {};

      "Mod+F".action.fullscreen-window = {};
      "Mod+Q".action.close-window = {};

      "Mod+Shift+E".action.quit = {};

      # Nested flags for actions
      "Mod+Ctrl+Shift+E".action.quit.skip-confirmation = true;

      "Mod+Shift+Slash".action.show-hotkey-overlay = {};

      "Mod+Plus".action.set-column-width = "+10%";
      "Mod+Minus".action.set-column-width = "-10%";
      "Mod+V".action.toggle-window-floating = {};
      "Mod+Shift+V".action.switch-focus-between-floating-and-tiling = {};
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
