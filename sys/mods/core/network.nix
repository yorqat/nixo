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
    # 6600 is mpd (usrs/mods/mpd); the rest are personal extras from setup, the
    # wired interface included.
    firewall.interfaces."${setup.firewall.lanInterface}" = {
      allowedTCPPorts = [6600] ++ setup.firewall.extraTCPPorts;
      allowedTCPPortRanges = setup.firewall.extraTCPPortRanges;
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

    # Cloudflare servers. Anycast, so a PH client gets a nearby POP rather than
    # a SEA resolver that blocks sites.
    nameservers = ["1.1.1.1" "1.0.0.1"];
  };

  # `networking.nameservers` above only sets systemd-resolved's *global* scope,
  # and the router hands out 192.168.254.254 over DHCP, which resolved treats as
  # link-scoped DNS for the wired interface. Left alone it may answer from the
  # router's resolver and defeat the point. Negative DNSPriority makes the
  # global Cloudflare pair win while keeping the router as a fallback, so losing
  # Cloudflare degrades to ISP DNS rather than to no DNS at all.
  services.resolved.settings.Resolve.DNSPriority = -50;
}
