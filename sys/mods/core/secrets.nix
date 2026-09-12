{
  config,
  lib,
  setup,
  ...
}: let
  # generic secrets machinery; everything personal lives in setup.secrets
  # (see setup/default.nix). payloads are whole files (keys, tokens), not
  # yaml/json docs. files must be git-tracked to be seen by the flake
  # (git add secrets/ after staging).
  secretsDir = ../../../secrets;

  payloads =
    lib.filterAttrs
    (name: type: type == "regular" && name != ".gitkeep" && !lib.hasPrefix "." name && !lib.hasSuffix "~" name && !lib.hasSuffix ".swp" name)
    (builtins.readDir secretsDir);

  rootSecrets =
    builtins.filter (name: lib.elem name (builtins.attrNames payloads))
    (setup.secrets.root or []);

  # payloads deploy to ~/.config/secrets/<name> unless pinned home-relative
  # in setup.secrets.deployPaths
  deployPath = name:
    "${setup.homeDir}/"
    + (setup.secrets.deployPaths.${name} or ".config/secrets/${name}");

  # secrets exported as env vars: payload name -> variable name, rendered
  # into ~/.config/secrets/env (sourced by the shell module)
  envNames = setup.secrets.envNames or {};
  envAvailable = builtins.filter (name: lib.hasAttr name payloads) (builtins.attrNames envNames);
in {
  # parent dirs for deployed secrets; sops-nix runs after tmpfiles
  systemd.tmpfiles.rules = [
    "d ${setup.homeDir}/.ssh 0700 ${setup.userName} users - -"
    "d ${setup.homeDir}/.config/secrets 0700 ${setup.userName} users - -"
  ];

  sops = lib.optionalAttrs (payloads != {} || rootSecrets != []) {
    age.keyFile = "/persist/var/lib/sops-nix/key.txt";

    defaultSopsFormat = "binary";

    secrets =
      (lib.mapAttrs (name: _: {
          sopsFile = secretsDir + "/${name}";
          path = deployPath name;
          owner = setup.userName;
          group = "users";
          mode = "0600";
        })
        (removeAttrs payloads rootSecrets))
      // (builtins.listToAttrs (map
        (name: {
          inherit name;
          value = {
            sopsFile = secretsDir + "/${name}";
            owner = "root";
            group = "root";
            mode = "0400";
            neededForUsers = true;
          };
        })
        rootSecrets));

    templates = lib.optionalAttrs (envAvailable != []) {
      # rendered at activation from decrypted values; sourced by the shell
      "secrets-env" = {
        content = lib.concatStrings (map
          (name: "export ${envNames.${name}}=${config.sops.placeholder."${name}"}\n")
          envAvailable);
        path = "${setup.homeDir}/.config/secrets/env";
        owner = setup.userName;
        group = "users";
        mode = "0600";
      };
    };
  };
}
