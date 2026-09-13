{...}: {
  # root is blank at boot; only these persist. /home is persisted wholesale.
  # modules append to environment.persistence."/persist" to register their
  # own state.
  environment.persistence."/persist" = {
    hideMounts = true;
    directories = [
      "/home"
      "/var/log"
      "/var/lib/bluetooth"
      "/var/lib/nixos"
      "/var/lib/systemd/coredump"
      "/var/lib/NetworkManager"
    ];
    files = [
      "/etc/machine-id"
      {
        file = "/var/lib/sops-nix/key.txt";
        parentDirectory = {
          mode = "0700";
        };
      }
    ];
  };
}
