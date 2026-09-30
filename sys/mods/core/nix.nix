{
  pkgs,
  lib,
  setup,
  ...
}: {
  # Not a no-op: the option default is [ perl rsync strace ]
  # (nixos/modules/config/system-path.nix:53). This drops them from
  # /run/current-system/sw.
  environment.defaultPackages = [];

  # allowBroken/allowInsecure are already false upstream
  # (pkgs/top-level/config.nix:279).
  nixpkgs.config.allowUnfree = true;

  nix = {
    package = pkgs.nixVersions.stable;
    settings = {
      # mkForce, not a union: the default is [ "root" ]
      # (nixos/modules/config/nix.nix:443), which produced "root root yor".
      trusted-users = lib.mkForce [
        "root"
        setup.userName
      ];
      auto-optimise-store = true;
      # cache.nixos.org's key is set by nixos/modules/config/nix.nix:442;
      # niri.cachix.org by the niri-flake cache module (flake.nix:480-481 of
      # niri-flake), toggleable with niri-flake.cache.enable.
      trusted-public-keys = [
        "fortuneteller2k.cachix.org-1:kXXNkMV5yheEQwT0I4XYh1MaCSz+qg72k8XAi2PthJI="
        "nixpkgs-wayland.cachix.org-1:3lwxaILxMRkVhehr5StQprHdEo4IrE8sRho9R9HOLYA="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
      substituters = [
        "https://cache.nixos.org?priority=10"
        "https://fortuneteller2k.cachix.org"
        "https://nixpkgs-wayland.cachix.org"
        "https://nix-community.cachix.org"
      ];
      # An option, not extraOptions: the option default is [ ]
      # (nixos/modules/config/nix.nix:257), so extraOptions emitted a stray
      # empty "experimental-features =" line ahead of the real one.
      experimental-features = [
        "nix-command"
        "flakes"
      ];
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 4d";
    };
  };

  system.stateVersion = setup.stateVersion;
}
