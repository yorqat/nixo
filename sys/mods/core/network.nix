{
  pkgs,
  hostname,
  ...
}: {
  networking = {
    firewall.enable = false;
    hostName = hostname;

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
