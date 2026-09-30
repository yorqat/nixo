{
  inputs = {
    nixpkgs = {
      url = "github:nixos/nixpkgs/nixos-unstable";
    };

    nixvim = {
      url = "github:nix-community/nixvim";
    };

    stylix = {
      url = "github:nix-community/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixpkgs-wayland = {
      url = "github:nix-community/nixpkgs-wayland";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # secure boot
    lanzaboote = {
      url = "github:nix-community/lanzaboote";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # secrets
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # stateful paths on a blank root
    impermanence = {
      url = "github:nix-community/impermanence";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {self, ...} @ inputs: let
    system = "x86_64-linux";
    # devshell-only nixpkgs: the system gets its own from nixosSystem.
    # Free-only, so that `nix develop` works without touching ~/.config/nixpkgs.
    # Adding an unfree package here needs `config.allowUnfree = true` back.
    pkgs = import inputs.nixpkgs {inherit system;};
  in {
    nixosConfigurations = import ./sys inputs;

    devShells.x86_64-linux.default = pkgs.callPackage ./devshell {};
  };
}
