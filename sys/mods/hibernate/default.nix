{config, ...}: {
  fileSystems."/swap" = {
    device = config.fileSystems."/".device;
    fsType = "btrfs";
    options = ["subvol=@swap" "noatime"];
  };

  swapDevices = [
    {
      device = "/swap/swapfile";
      size = 34 * 1024;
    }
  ];
}
