{pkgs, ...}: let
  # See scripts/bt-autoconnect.sh for the logic.
  autoconnect = pkgs.writeShellScript "bt-autoconnect" (
    builtins.replaceStrings
    ["@bluetoothctl@"]
    ["${pkgs.bluez}/bin/bluetoothctl"]
    (builtins.readFile ../../../scripts/bt-autoconnect.sh)
  );
in {
  # Connect paired devices once the session is up. This has to be a user service
  # (unlike the resume hook): an A2DP connection only sticks once WirePlumber is
  # running, and a system unit fires before login, so the connect silently
  # no-op'd. Anchored to niri.service's lifetime like eww.
  systemd.user.services.bt-autoconnect = {
    Unit = {
      Description = "Connect paired Bluetooth devices";
      Wants = ["wireplumber.service"];
      After = ["wireplumber.service" "niri.service"];
      PartOf = ["niri.service"];
      # only meaningful inside a niri session; fail a manual start outside one
      Requisite = ["niri.service"];
    };
    Install.WantedBy = ["niri.service"];
    Service = {
      Type = "oneshot";
      ExecStart = autoconnect;
    };
  };
}
