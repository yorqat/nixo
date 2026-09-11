{
  pkgs,
  inputs,
  ...
}: {
  nixpkgs.overlays = [inputs.nixpkgs-wayland.overlay];
  environment = {
    variables = {
      NIXOS_OZONE_WL = "1";
      DISABLE_QT5_COMPAT = "0";
      ANKI_WAYLAND = "1";
      DIRENV_LOG_FORMAT = "";
      WLR_DRM_NO_ATOMIC = "1";

      QT_QPA_PLATFORM = "wayland";
      QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";

      MOZ_ENABLE_WAYLAND = "1";

      WLR_BACKEND = "vulkan";
      WLR_NO_HARDWARE_CURSORS = "1";
      XDG_SESSION_TYPE = "wayland";
      CLUTTER_BACKEND = "wayland";
    };
    loginShellInit = ''
      export GPG_TTY=$TTY
    '';
  };
}
