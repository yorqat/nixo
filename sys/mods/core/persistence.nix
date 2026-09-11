{...}: {
  # conservative start: whole trees persist, root is blank at boot.
  # phase 3 tightens this to per-app enumeration.
  environment.persistence."/persist" = {
    hideMounts = true;
    directories = [
      "/var/log"
      "/var/lib/bluetooth"
      "/var/lib/nixos"
      "/var/lib/systemd/coredump"
      "/var/lib/NetworkManager"
      "/home"
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
