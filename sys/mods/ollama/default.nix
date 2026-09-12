{
  lib,
  pkgs,
  ...
}: let
  host = "127.0.0.1";
  port = "11434";
  base = "http://${host}:${port}";

  # CLI shim: boots the daemon on first use instead of at every boot.
  # shadows the real binary via PATH (see mkBefore below)
  ollamaShim = pkgs.writeShellScriptBin "ollama" ''
    set -euo pipefail
    if ! ${pkgs.curl}/bin/curl -sf ${base}/api/version >/dev/null; then
      systemctl start ollama
      for _ in $(seq 1 120); do
        ${pkgs.curl}/bin/curl -sf ${base}/api/version >/dev/null && break
        sleep 0.5
      done
      if ! ${pkgs.curl}/bin/curl -sf ${base}/api/version >/dev/null; then
        printf 'error: ollama daemon did not come up\n' >&2
        exit 1
      fi
    fi
    exec ${pkgs.ollama}/bin/ollama "$@"
  '';
in {
  services.ollama.enable = true;

  # on-demand: nothing listens at boot; the shim above starts it and the
  # idle-stop timer ends it once models unload (keep_alive defaults to 5m)
  systemd.services.ollama.wantedBy = lib.mkForce [];

  # wheel can start/stop the daemon without a password prompt
  environment.etc."polkit-1/rules.d/10-ollama.rules".text = ''
    polkit.addRule(function(action, subject) {
      if (action.id == "org.freedesktop.systemd1.manage-units" &&
          subject.isInGroup("wheel") &&
          action.lookup("unit") == "ollama.service") {
        return polkit.Result.YES;
      }
    });
  '';

  environment.systemPackages = lib.mkBefore [ollamaShim];

  systemd.services.ollama-idle-stop = {
    serviceConfig.Type = "oneshot";
    script = ''
      systemctl is-active --quiet ollama || exit 0
      ps_json="$(${pkgs.curl}/bin/curl -sf ${base}/api/ps)" || exit 0
      if [ "$(${pkgs.jq}/bin/jq '.models | length' <<<"$ps_json")" = "0" ]; then
        systemctl stop ollama
      fi
    '';
  };
  systemd.timers.ollama-idle-stop = {
    wantedBy = ["timers.target"];
    timerConfig = {
      OnCalendar = "*:0/10";
      Unit = "ollama-idle-stop.service";
    };
  };

  # whole /var/lib is not persisted; models must be
  environment.persistence."/persist".directories = ["/var/lib/ollama"];
}
