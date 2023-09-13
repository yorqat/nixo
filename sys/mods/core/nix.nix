{
  pkgs,
  inputs,
  ...
}: let
  hyprland-nvidia = inputs.hyprland.packages.${pkgs.system}.default.override {
    wlroots = inputs.hyprland.packages.${pkgs.system}.wlroots-hyprland;

    enableNvidiaPatches = true;
  };

  hyprland = inputs.hyprland.packages.${pkgs.system}.default;
in {
  environment.defaultPackages = [];

  nixpkgs.config = {
    allowUnfree = true;
    allowBroken = false;
  };

  nixpkgs.overlays = [
    inputs.xdg-desktop-portal-hyprland.overlays.default
    (final: super: {
      makeModulesClosure = x:
        super.makeModulesClosure (x // {allowMissing = true;});

      inherit hyprland-nvidia hyprland;
    })
  ];

  nix = {
    package = pkgs.nixStable;
    settings = {
      trusted-users = ["root" "yor"];
      auto-optimise-store = true;
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "fortuneteller2k.cachix.org-1:kXXNkMV5yheEQwT0I4XYh1MaCSz+qg72k8XAi2PthJI="
        "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
        "webcord.cachix.org-1:l555jqOZGHd2C9+vS8ccdh8FhqnGe8L78QrHNn+EFEs="
        "nixpkgs-wayland.cachix.org-1:3lwxaILxMRkVhehr5StQprHdEo4IrE8sRho9R9HOLYA="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
      substituters = [
        "https://cache.nixos.org?priority=10"
        "https://fortuneteller2k.cachix.org"
        "https://hyprland.cachix.org"
        "https://webcord.cachix.org"
        "https://nixpkgs-wayland.cachix.org"
        "https://nix-community.cachix.org"
      ];
    };
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 4d";
    };
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "22.11"; # Did you read the comment tho
}
