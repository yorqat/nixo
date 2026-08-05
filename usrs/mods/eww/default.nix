{
  pkgs,
  lib,
  config,
  ...
}: let
  mkService = lib.recursiveUpdate {
    Unit.PartOf = ["niri.service"];
    Unit.After = ["niri.service"];
    Install.WantedBy = ["niri.service"];
  };

  colors = config.lib.stylix.colors.withHashtag;

  # regenerated whenever the active Stylix scheme/specialisation changes
  themeScss = pkgs.writeText "eww-theme.scss" ''
    $bg: ${colors.base00};
    $bg-alt: ${colors.base01};
    $bg-select: ${colors.base02};
    $fg-dim: ${colors.base03};
    $fg: ${colors.base05};
    $fg-bright: ${colors.base06};
    $accent: ${colors.base0D};
    $accent-alt: ${colors.base0E};
    $warn: ${colors.base08};
    $mono-font: "${config.stylix.fonts.monospace.name}";
  '';

  ewwConfig = pkgs.runCommand "eww-config" {} ''
    mkdir -p $out
    cp -r ${./config}/. $out/
    cp ${themeScss} $out/theme.scss
  '';
in {
  home.packages = with pkgs; [alsa-utils];

  programs.eww.enable = true;

  xdg.configFile."eww".source = ewwConfig;

  systemd.user.services.eww = mkService {
    Unit.Description = "eww widgets";
    Service = {
      ExecStart = "${pkgs.eww}/bin/eww daemon --no-daemonize";
      ExecStartPost = "${pkgs.eww}/bin/eww open-many bar mp-mini notify-mini";
      Restart = "on-failure";
    };
  };
}
