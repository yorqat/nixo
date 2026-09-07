{inputs, ...}: {
  nixpkgs.overlays = [inputs.nixpkgs-wayland.overlay];

  environment = {
    variables = {
      XDG_SESSION_TYPE = "wayland";
      NIXOS_OZONE_WL = "1";
      DIRENV_LOG_FORMAT = "";
      QT_QPA_PLATFORM = "wayland";
      QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
      MOZ_ENABLE_WAYLAND = "1";
    };
    loginShellInit = ''
      export GPG_TTY=$TTY
    '';
  };
}
