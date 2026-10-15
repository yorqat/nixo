{pkgs, ...}: let
  # See scripts/bt-autoconnect.sh; @bluetoothctl@ is filled in here because a
  # system service's PATH does not include bluez.
  autoconnect = pkgs.writeShellScript "bt-autoconnect" (
    builtins.replaceStrings
    ["@bluetoothctl@"]
    ["${pkgs.bluez}/bin/bluetoothctl"]
    (builtins.readFile ../../../scripts/bt-autoconnect.sh)
  );
in {
  # Reconnect as fast as BlueZ allows, both right after boot (devices come back
  # in range with a 1s retry instead of a 1,2,4,8... backoff) and on resume
  # from suspend (BlueZ reconnects audio devices itself, via ResumeDelay). All
  # three live under [Policy]; see bluez's own src/main.conf for the rest.
  hardware.bluetooth = {
    enable = true;

    settings.Policy = {
      # Attempts to reconnect after a link is lost. Note 0 *disables*
      # reconnection entirely; the default is 7. Go well above both so a
      # dropped device keeps coming back instead of giving up.
      ReconnectAttempts = 64;

      # Seconds between those attempts; the last entry is reused for any
      # remaining attempts. The default 1,2,4,8,16,32,64 backs off -- pin them
      # all to 1s so it never does.
      ReconnectIntervals = "1,1,1,1,1,1,1";

      # Delay between the controller resuming from suspend and the first
      # reconnect attempt for audio devices. Default 2s (kinder to Wi-Fi/BT
      # co-existence); 0 = reconnect the instant the controller is back. The
      # attempts/intervals above cover the case where that first try loses a
      # race and needs a retry.
      ResumeDelay = 0;
    };
  };

  services.blueman.enable = true;

  # Login-time connect is a user service (usrs/mods/bluetooth) -- a system one
  # runs before login, when WirePlumber is not up, and silently does nothing.
  # What is left for the system side is resume, which the user manager cannot
  # hook (it exposes no sleep.target): systemd stops this unit once sleep.target
  # deactivates (StopWhenUnneeded), and ExecStop is the bit that runs on wake.
  # It is wanted only by sleep.target so "no longer needed" genuinely becomes
  # true on wake -- being wanted by multi-user.target too would keep it needed
  # across suspend and it would never fire ExecStop.
  systemd.services.bt-autoconnect-resume = {
    description = "Reconnect paired Bluetooth devices on resume";
    wantedBy = ["sleep.target"];
    before = ["sleep.target"];
    wants = ["bluetooth.service"];
    after = ["bluetooth.service"];
    unitConfig.StopWhenUnneeded = true;
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.coreutils}/bin/true";
      ExecStop = autoconnect;
    };
  };
}
