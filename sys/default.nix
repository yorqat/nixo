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
  
  yor = ../usrs/yor.nix;
  setup = import ../setup;
in {
  qat = nixpkgs.lib.nixosSystem {
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

      nvidia
      wayland

      # secure boot requirement
      lbtModule

      # firefox extensions
      { nixpkgs.overlays = [ inputs.nur.overlay ]; }

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
          users."${setup.userName}" = yor;
        };
      }
    ];
  };
}
