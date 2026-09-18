{pkgs, ...}: let
  # Disposable Chromium: a brand-new, empty profile on every launch, deleted on
  # exit. No history, cookies, logins or cache survive a close, and nothing is
  # ever written to ~/.config/chromium. /tmp is tmpfs, so a crash still wipes it
  # on reboot.
  chromiumGuest = pkgs.writeShellScriptBin "chromium-guest" ''
    dir="$(mktemp -d "''${TMPDIR:-/tmp}/chromium-guest.XXXXXX")"
    trap 'rm -rf "$dir"' EXIT INT TERM
    ${pkgs.chromium}/bin/chromium \
      --user-data-dir="$dir" \
      --no-first-run \
      --no-default-browser-check \
      "$@"
  '';
in {
  home.packages = [chromiumGuest];

  xdg.desktopEntries."chromium-guest" = {
    name = "Chromium (Guest)";
    comment = "Disposable Chromium session — fresh profile every launch, wiped on close";
    exec = "chromium-guest %U";
    icon = "chromium";
    type = "Application";
    categories = [
      "Network"
      "WebBrowser"
    ];
    terminal = false;
  };
}
