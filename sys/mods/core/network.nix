{setup, ...}: {
  networking = {
    # nftables rather than the legacy iptables backend; nixpkgs still defaults
    # the firewall to iptables unless this is set.
    nftables.enable = true;
    firewall = {
      enable = true;
      # 22 is already contributed by services.openssh.openFirewall and 5353 by
      # avahi's. Stated explicitly so that flipping either openFirewall = false
      # cannot silently drop ssh while this stays true. Note 5355 (avahi's LLMNR)
      # is deliberately absent: it is legacy and closed by default.
      allowedTCPPorts = [22]; # ssh
      allowedUDPPorts = [5353]; # mDNS
    };
    # LAN-scoped: mpd for phone streaming, and the vite/svelte dev servers.
    # Scoped rather than global because a vite dev server has a history of
    # arbitrary-file-read CVEs, and iifname keeps it off wifi/USB-tether even
    # while the port is open.
    firewall.interfaces.eno1 = {
      allowedTCPPorts = [6600]; # mpd
      allowedTCPPortRanges = [
        {
          from = 4173;
          to = 4180;
        }
        {
          from = 5173;
          to = 5180;
        }
      ];
    };
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

    # Cloudflare servers
    nameservers = ["1.1.1.1" "1.0.0.1"];
  };
}
