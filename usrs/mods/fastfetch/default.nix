{
  pkgs,
  lib,
  config,
  ...
}: {
  home.packages = [pkgs.fastfetch];

  xdg.configFile = {
    "fastfetch/nix-original.png".source = ./config/nix-original.png;
    "fastfetch/nix-light.png".source = ./config/nix-light.png;
    "fastfetch/config.jsonc".text = builtins.toJSON {
      "$schema" = "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json";
      logo = {
        type = "kitty-direct";
        source = "${config.home.homeDirectory}/.config/fastfetch/nix-original.png";
        width = 22;
        preserveAspectRatio = true;
        padding.right = 7;
      };
      display = {
        separator = "    ";
        percent.type = 1;
      };
      modules = [
        "title"
        {
          type = "de";
          key = "󰧨";
        }
        {
          type = "custom";
          format = "────────────────────────────";
        }
        {
          type = "kernel";
          key = "󰞸";
        }
        {
          type = "packages";
          key = "󰏖";
        }
        {
          type = "uptime";
          key = "󰥔";
        }
        {
          type = "custom";
          format = "────────────────────────────";
        }
        {
          type = "cpu";
          key = "󰻠";
          format = "{name}";
          percent = {type = 3;};
        }
        {
          type = "memory";
          key = "";
          percent = {type = 3;};
        }
        {
          type = "gpu";
          key = "";
        }
        {
          type = "custom";
          format = "────────────────────────────";
        }
      ];
    };
  };
}
