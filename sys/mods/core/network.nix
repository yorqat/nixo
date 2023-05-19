{ pkgs, hostname, ... }:
{
  networking = {
    firewall.enable = false;
    hostName = hostname;
    networkmanager.enable = true;
  };
}
