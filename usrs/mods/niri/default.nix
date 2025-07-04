{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:
{
  home.packages = with pkgs; [
    libnotify
    wf-recorder
    brightnessctl
    pamixer
    # python39Packages.requests
    slurp
    tesseract5
    grim
    wl-clipboard
    pngquant
    # swww
    libsForQt5.qt5.qtwayland

    xwayland-satellite

    wofi
    mako
    swaybg
    libnotify
    imv
  ];

  programs.niri.settings = {
    prefer-no-csd = true;

    spawn-at-startup = [
      { command = [ "swaybg --image ~/.config/eww/image/stitch_wall.png --mode fill" ]; }
      { command = [ "xwayland-satellite" ]; }
    ];

    environment = {
      DISPLAY = ":0";
    };

    window-rules = [
    
    ];

    binds = with config.lib.niri.actions; {
      "XF86AudioRaiseVolume".action = spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "0.1+";
      "XF86AudioLowerVolume".action = spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "0.1-";
      "Mod+M".action = power-off-monitors;

      "Mod+D".action = spawn "wofi" "--show" "drun" "--columns" "3" "--gtk-dark"  "--allow-images" "--fork";
      "Mod+0".action = spawn "kitty";

      "Mod+Up".action = focus-window-up;
      "Mod+Down".action = focus-window-down;
      "Mod+Left".action = focus-column-left;
      "Mod+Right".action = focus-column-right;

      "Mod+K".action = focus-window-up;
      "Mod+J".action = focus-window-down;
      "Mod+H".action = focus-column-left;
      "Mod+L".action = focus-column-right;

      "Mod+BracketLeft".action = consume-or-expel-window-left;
      "Mod+BracketRight".action = consume-or-expel-window-right;

      "Mod+1".action = focus-workspace 1;
      "Mod+2".action = focus-workspace 2;
      "Mod+3".action = focus-workspace 3;
      "Mod+4".action = focus-workspace 4;
      "Mod+5".action = focus-workspace 5;
      "Mod+6".action = focus-workspace 6;
      "Mod+7".action = focus-workspace 7;
      "Mod+8".action = focus-workspace 8;
      "Mod+9".action = focus-workspace 9;

      "Mod+F".action = fullscreen-window;
      "Mod+Q".action = close-window;

      "Mod+Shift+E".action = quit;
      "Mod+Ctrl+Shift+E".action = quit { skip-confirmation=true; };
      "Mod+Shift+Slash".action = show-hotkey-overlay;

      "Mod+Plus".action = set-column-width "+10%";
      "Mod+Minus".action = set-column-width "-10%";
      "Mod+V".action = toggle-window-floating;
      "Mod+Shift+V".action = switch-focus-between-floating-and-tiling;
    };

  };
}
