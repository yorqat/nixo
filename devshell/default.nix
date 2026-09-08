{pkgs, ...}: let
  secrets = pkgs.writeShellScriptBin "secrets" (builtins.readFile ./secrets.sh);
in
  pkgs.mkShell {
    packages = [
      secrets
      pkgs.sops
      pkgs.age
      pkgs.yaml-language-server # yaml LSP
      pkgs.alejandra # uncomprimising nix formatter
      pkgs.fnlfmt # fennel formatter
      pkgs.stylua # lua formatter
      pkgs.claude-code
    ];
  }
