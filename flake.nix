{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    # nixpkgs.url = "github:nixos/nixpkgs/nixos";

    hyprland = { 
      # url = "github:hyprwm/Hyprland/";
      url = "github:hyprwm/Hyprland/896a78aaa0bb2e4d4f197ed1286c4f030dbaef5f";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hyprland-contrib.url = "github:hyprwm/contrib";

    xdg-desktop-portal-hyprland = {
      # url = "github:hyprwm/xdg-desktop-portal-hyprland";
      url = "github:hyprwm/xdg-desktop-portal-hyprland/bf035bf3d5b56fd3da9d11966ad0b3c57f852d78";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixpkgs-wayland = {
      url = "github:nix-community/nixpkgs-wayland";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {self, ...} @ inputs: let
    system = "x86_64-linux";
    # pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
    pkgs = import inputs.nixpkgs {
      inherit system;
    };
  in {
    nixosConfigurations = import ./sys inputs;

    devShells.x86_64-linux.default = pkgs.mkShell {
      packages = with pkgs; [
        rnix-lsp # nix LSP
        yaml-language-server # yaml LSP
        alejandra # uncomprimising nix formatter
        fnlfmt # fennel formatter
      ];
    };
  };
}
