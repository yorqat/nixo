{
  pkgs,
  inputs,
  ...
}: {
  nixpkgs.overlays = [inputs.nixpkgs-wayland.overlay];

  environment = {
    variables = {
      NIXOS_OZONE_WL = "1";
      __GL_GSYNC_ALLOWED = "0";
      __GL_VRR_ALLOWED = "0";
      DISABLE_QT5_COMPAT = "0";
      ANKI_WAYLAND = "1";
      DIRENV_LOG_FORMAT = "";
      WLR_DRM_NO_ATOMIC = "1";

      QT_QPA_PLATFORM = "wayland";
      QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
      # QT_QPA_PLATFORMTHEME = "qt5ct";
      # QT_STYLE_OVERRIDE = "kvantum";

      MOZ_ENABLE_WAYLAND = "1";

      WLR_BACKEND = "vulkan";
      WLR_NO_HARDWARE_CURSORS = "1";
      XDG_SESSION_TYPE = "wayland";
      CLUTTER_BACKEND = "wayland";
      # WLR_DRM_DEVICES = "/dev/dri/card1:/dev/dri/card0";
    };
    loginShellInit = ''
      # dbus-update-activation-environment --systemd DISPLAY
      # eval $(ssh-agent)
      # eval $(gnome-keyring-daemon --start)
      export GPG_TTY=$TTY
    '';
  };

  #xdg.portal = {
    #enable = true;
    #extraPortals = [pkgs.xdg-desktop-portal-hyprland];
  #};
}
