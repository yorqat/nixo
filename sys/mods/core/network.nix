{setup, ...}: {
  networking = {
    firewall.enable = false;
    hostName = setup.hostName;

    timeServers = [
      "0.asia.pool.ntp.org"
      "1.asia.pool.ntp.org"
      "2.asia.pool.ntp.org"
      "3.asia.pool.ntp.org"
    ];

    networkmanager = {
      enable = true;
    };
  };
}
