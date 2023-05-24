{
  nixpkgs,
  self,
  ...
}: let
  inputs = self.inputs;
  bootloader = ./mods/core/boot;
  core = ./mods/core;
  #intel = ./modules/intel;
  nvidia = ./mods/nvidia;
  wayland = ./mods/wayland;
  #printing = ./mods/printing;
  #teamviewer = ./mods/teamviewer;
  hmModule = inputs.home-manager.nixosModules.home-manager;

  yor = ../usrs/yor.nix;
in {
  qat = nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = {
      inherit inputs;
      hostname = "qat";
    };
    modules = [
      ../hardware-configuration.nix
      ./host
      bootloader
      core

      nvidia
      wayland

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
          users.yor = yor;
        };
      }
    ];
  };
}
