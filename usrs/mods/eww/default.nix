{
  pkgs,
  lib,
  config,
  ...
}: let
  # niri's recommended companion-service pattern (wiki: Example-systemd-Setup):
  # pull the unit into niri's session via niri.service.wants, and anchor its
  # lifetime to the compositor. eww is niri-specific (every action is a
  # `niri msg`), so anchor to niri.service rather than the generic
  # graphical-session.target: it starts at niri's READY=1 (Type=notify) and
  # dies with niri, so it never runs under another session.
  mkService = lib.recursiveUpdate {
    Unit.PartOf = ["niri.service"];
    Unit.After = ["niri.service"];
    # fail the start if niri is not active, e.g. a manual
    # `systemctl --user start eww` outside the session
    Unit.Requisite = ["niri.service"];
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
  programs.eww.enable = true;

  xdg.configFile."eww".source = ewwConfig;

  systemd.user.services.eww = mkService {
    Service = {
      ExecStart = "${pkgs.eww}/bin/eww daemon --no-daemonize";
      # Bounded retry: the daemon's IPC socket may not be ready the instant
      # ExecStartPost runs. If it still fails after ~10s, fail the start so
      # Restart=always gives a supervised retry instead of a stuck unit.
      ExecStartPost = "${lib.getExe pkgs.dash} -c 'i=0; while [ $i -lt 100 ]; do if ${pkgs.eww}/bin/eww open-many bar mp-mini notify-mini; then exit 0; fi; i=$((i+1)); sleep 0.1; done; exit 1'";
      Restart = "always";
      RestartSec = "1s";
    };
  };
}
