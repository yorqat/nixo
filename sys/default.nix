{
  nixpkgs,
  self,
  ...
}: let
  inputs = self.inputs;
  lib = nixpkgs.lib;
  setup = import ../setup;

  hmModule = inputs.home-manager.nixosModules.home-manager;
  lbtModule = inputs.lanzaboote.nixosModules.lanzaboote;
  sopsModule = inputs.sops-nix.nixosModules.sops;
  impermanenceModule = inputs.impermanence.nixosModules.impermanence;
  niriModule = inputs.niri.nixosModules.niri;
  stylixModule = inputs.stylix.nixosModules.stylix;

  userDefault = ../usrs;
in {
  "${setup.hostName}" = nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    # the single pass: setup travels to every module from here —
    # never `import ../setup` inside a module
    specialArgs = {
      inherit inputs setup;
    };
    modules =
      [
        ../hardware-configuration.nix
        ./host
        ./mods/core
        ./mods/wayland

        # secure boot requirement
        lbtModule

        # secrets
        sopsModule

        # persistence
        impermanenceModule

        # firefox extensions
        {nixpkgs.overlays = [inputs.nur.overlays.default];}

        niriModule
        stylixModule

        hmModule
        {
          home-manager = {
            useUserPackages = true;
            useGlobalPkgs = true;
            backupFileExtension = "bak";
            extraSpecialArgs = {
              inherit inputs setup;
              inherit self;
              packages = self.packages."x86_64-linux";
            };
            users."${setup.userName}" = userDefault;
          };
        }
      ]
      # gpu: only with a matching card, so fresh installs stay bootable
      ++ lib.optional setup.includes.nvidia ./mods/nvidia;
  };
}
