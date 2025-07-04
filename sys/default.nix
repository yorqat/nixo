{
  nixpkgs,
  self,
  ...
}: let
  inputs = self.inputs;
  bootloader = ./mods/core/boot;
  core = ./mods/core;
  nvidia = ./mods/nvidia;
  wayland = ./mods/wayland;
  #printing = ./mods/printing;
  hmModule = inputs.home-manager.nixosModules.home-manager;
  lbtModule = inputs.lanzaboote.nixosModules.lanzaboote;
  niriModule = inputs.niri.nixosModules.niri;
  
  userDefault = ../usrs;
  setup = import ../setup;
in {
  "${setup.hostName}" = nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = {
      inherit inputs;
      hostname = "${setup.hostName}";
    };
    modules = [
      ../hardware-configuration.nix
      ./host
      bootloader
      core

      # nvidia
      wayland

      # secure boot requirement
      lbtModule

      # firefox extensions
      { nixpkgs.overlays = [ inputs.nur.overlays.default ]; }

      niriModule

      hmModule
      {
        home-manager = {
          useUserPackages = true;
          useGlobalPkgs = true;
          extraSpecialArgs = {
            inherit inputs;
            inherit self;
            packages = self.packages."x86_64-linux";
          };
          users."${setup.userName}" = userDefault;
        };
      }
    ];
  };
}
