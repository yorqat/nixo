# THE config. everything personal lives here.
# system modules read this via specialArgs (see sys/default.nix) — import it nowhere else.
let
  userName = "yor";
  hostName = "qat";
  homeDir = "/home/${userName}";

  # lite = fresh-install-safe profile: niri + core apps only, nothing that
  # assumes this machine (nvidia gpu, ollama daemon, plasma6). flip to false
  # on hardware that actually has those things.
  lite = false;
in {
  inherit userName hostName homeDir;

  timeZone = "Asia/Manila";
  defaultLocale = "en_PH.UTF-8";
  extraLocale = "fil_PH";

  # /dat is a mountpoint for media and documents.
  # secrets are managed by sops-nix, not symlinks (see migrate-cred.sh)
  symLinks = [
    # [ "dest" "src" ]
    ["${homeDir}/Documents" "/dat/Documents"]
    ["${homeDir}/Downloads" "/dat/Downloads"]
    ["${homeDir}/Videos" "/dat/Videos"]
    ["${homeDir}/Pictures" "/dat/Pictures"]
    ["${homeDir}/Music" "/dat/Music"]

    ["${homeDir}/my-nixos" "/dat/Documents/my-nixos"]
  ];

  # every git-tracked file in secrets/ deploys to ~/.config/secrets/<name>.
  # the personal bits:
  #   deployPaths  payload -> home-relative path, for keys/dotfiles that
  #                belong somewhere else (e.g. ".ssh/id_ed25519")
  #   envNames     payload -> env var name, exported via ~/.config/secrets/env
  #   root         payloads deployed root-owned (account hashes, neededForUsers)
  secrets = {
    deployPaths = {
      "id_ed25519" = ".ssh/id_ed25519";
      "id_ed25519.pub" = ".ssh/id_ed25519.pub";
      "id_gitlab" = ".ssh/id_gitlab";
      "id_gitlab.pub" = ".ssh/id_gitlab.pub";
      "wakatime.cfg" = ".wakatime.cfg";
    };

    envNames = {
      "openrouter-api-key" = "OPENROUTER_API_KEY";
    };

    root = ["yor-password-hash"];
  };

  includes = {
    # heavyweight / machine-specific — these are what lite mode gates
    nvidia = !lite;
    ollama = !lite;
    plasma6 = !lite;

    # opt-in extras, off on any profile
    steam = false;
    virt-manager = false;
    libreoffice = false;
    minecraftPrismLauncher = false;
  };

  # enable only after enrolling your own keys into /etc/secureboot
  secureBoot.lanzaboote = false;

  # only change on fresh install
  stateVersion = "25.11";

  # Home manager
  homeManagerVersion = "26.05";
}
