{
  lib,
  setup,
  ...
}: let
  # generic persistence machinery; the per-app home enumeration lives in
  # setup.persist (see setup/default.nix). modules append to
  # environment.persistence."/persist" to register their own state.
  home = setup.homeDir;
  persist = setup.persist;
in {
  # root is blank at boot; only these persist.
  environment.persistence."/persist" = {
    hideMounts = true;
    directories =
      [
        "/var/log"
        "/var/lib/bluetooth"
        "/var/lib/nixos"
        "/var/lib/systemd/coredump"
        "/var/lib/NetworkManager"
      ]
      ++ map (n: "${home}/${n}") persist.homeDirs;
    files =
      [
        "/etc/machine-id"
        {
          file = "/var/lib/sops-nix/key.txt";
          parentDirectory = {
            mode = "0700";
          };
        }
      ]
      ++ map (n: "${home}/${n}") persist.homeFiles;
  };
}
