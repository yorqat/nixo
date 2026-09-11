{
  lib,
  setup,
  ...
}: let
  # encrypted payloads live here; see migrate-cred.sh at the repo root
  # names must be git-tracked to be seen by the flake (git add secrets/ after migrating)
  secretsDir = ../../../secrets;

  userSecrets = [
    "id_ed25519"
    "id_ed25519.pub"
    "id_gitlab"
    "id_gitlab.pub"
    "wakatime.cfg"
  ];

  available = builtins.filter (name: builtins.pathExists (secretsDir + "/${name}")) userSecrets;

  deployPath = name:
    if name == "wakatime.cfg"
    then "${setup.homeDir}/.${name}"
    else "${setup.homeDir}/.ssh/${name}";
in {
  # parent dir for deployed ssh secrets; sops-nix runs after tmpfiles
  systemd.tmpfiles.rules = [
    "d ${setup.homeDir}/.ssh 0700 ${setup.userName} users - -"
  ];

  sops = lib.optionalAttrs (available != [] || builtins.pathExists (secretsDir + "/yor-password-hash")) {
    age.keyFile = "/persist/var/lib/sops-nix/key.txt";

    # payloads are whole files (keys, host lists), not yaml/json docs
    defaultSopsFormat = "binary";

    secrets =
      (builtins.listToAttrs (map
        (name: {
          inherit name;
          value = {
            sopsFile = secretsDir + "/${name}";
            path = deployPath name;
            owner = setup.userName;
            group = "users";
            mode = "0600";
          };
        })
        available))
      // (lib.optionalAttrs (builtins.pathExists (secretsDir + "/yor-password-hash")) {
        "yor-password-hash" = {
          sopsFile = secretsDir + "/yor-password-hash";
          owner = "root";
          group = "root";
          mode = "0400";
          neededForUsers = true;
        };
      });
  };
}
