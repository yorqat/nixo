{...}: {
  services.pipewire = {
    enable = true;

    wireplumber.enable = true;

    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };

  services.pulseaudio.enable = false;
  security.rtkit.enable = true;

  # WirePlumber's own Bluetooth-audio glue: better codecs (SBC-XQ, mSBC) and
  # headset roles for paired devices. Lives here (not in bluetooth.nix) because
  # it's Pipewire-side audio config, not BlueZ-side.
  environment.etc = {
    "wireplumber/bluetooth.lua.d/51-bluez-config.lua".text = "	bluez_monitor.properties = {\n		[\"bluez5.enable-sbc-xq\"] = true,\n		[\"bluez5.enable-msbc\"] = true,\n		[\"bluez5.enable-hw-volume\"] = true,\n		[\"bluez5.headset-roles\"] = \"[ hsp_hs hsp_ag hfp_hf hfp_ag ]\"\n	}\n";
  };
}
