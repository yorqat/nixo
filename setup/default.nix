# THE config. everything personal lives here.
# system modules read this via specialArgs (see sys/default.nix) — import it nowhere else.
let
  userName = "yor";
  hostName = "qat";
  homeDir = "/home/${userName}";

  # lite = fresh-install-safe profile: niri + core apps only, nothing that
  # assumes this machine (nvidia gpu, on-demand ollama, plasma6). flip to false
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

  # per-app persistence: these are bind-mounted from /persist at boot.
  # everything else in $HOME is blank on every boot — loose files dropped
  # in $HOME don't survive a reboot, add them here or keep them on /dat.
  persist = {
    # home-relative directories
    homeDirs = [
      # shell + dev
      ".ssh"
      ".gnupg"
      ".config/direnv"
      ".config/gh"
      ".config/git"
      ".local/share/direnv"
      ".local/share/zoxide"
      ".local/state/home-manager"
      ".local/state/nix"

      # editors + terminal
      ".config/nvim"
      ".config/kitty"
      ".config/opencode"
      ".local/share/nvim"
      ".local/share/opencode"
      ".local/state/nvim"
      ".local/state/opencode"

      # browsers + chat
      ".config/chromium"
      ".config/mozilla"
      ".config/discordcanary"
      ".config/Vencord"
      ".config/Signal"

      # media + misc apps
      ".config/blender"
      ".config/deluge"
      ".config/mpv"
      ".config/eww"
      ".config/fastfetch"
      ".config/gdu"
      ".local/share/mpd"

      # desktop stack, stack-agnostic bits (niri + plasma6 both live here)
      ".config/dconf"
      ".config/fontconfig"
      ".config/gtk-3.0"
      ".config/gtk-4.0"
      ".config/environment.d"
      ".config/systemd"
      ".config/user-tmpfiles.d"
      ".config/user-dirs.dirs"
      ".config/user-dirs.locale"
      ".config/niri"
      ".config/session"
      ".config/autostart"
      ".config/pulse"
      ".config/qt5ct"
      ".config/qt6ct"
      ".config/stylix"
      ".local/share/keyrings"
      ".local/share/pki"
      ".local/share/sddm"
      ".local/share/io.ente.auth"
      ".local/state/wireplumber"

      # plasma6 (drop this group when the stack is deduped)
      ".config/KDE"
      ".config/Kvantum"
      ".config/kdedefaults"
      ".config/kate"
      ".config/kate-externaltoolspluginrc"
      ".config/katerc"
      ".config/katevirc"
      ".config/kconf_updaterc"
      ".config/kded5rc"
      ".config/kded6rc"
      ".config/kdeglobals"
      ".config/kglobalshortcutsrc"
      ".config/kiorc"
      ".config/ksmserverrc"
      ".config/ktimezonedrc"
      ".config/kwalletrc"
      ".config/libaccounts-glib"
      ".config/Trolltech.conf"
      ".config/bluedevilglobalrc"
      ".config/dolphinrc"
      ".config/discoverrc"
      ".config/forge"
      ".config/gtkrc"
      ".config/gtkrc-2.0"
      ".config/gwenviewrc"
      ".config/kwinoutputconfig.json"
      ".config/kwinrc"
      ".config/kwinrulesrc"
      ".config/plasma-localerc"
      ".config/plasma-org.kde.plasma.desktop-appletsrc"
      ".config/plasmashellrc"
      ".config/powerdevilrc"
      ".config/powermanagementprofilesrc"
      ".local/share/dolphin"
      ".local/share/gwenview"
      ".local/share/kate"
      ".local/share/klipper"
      ".local/share/knewstuff3"
      ".local/share/kwalletd"
      ".local/state/dolphinstaterc"
      ".local/state/discoverstaterc"
      ".local/state/gwenviewstaterc"
      ".local/state/katestaterc"
      ".local/state/kglobalshortcutsstaterc"
      ".local/state/kickerstaterc"
      ".local/state/plasmasessionrestorestaterc"
      ".local/state/plasmashellstaterc"
    ];

    # home-relative files
    homeFiles = [
      ".bash_history"
      ".local/share/user-places.xbel"
      ".local/share/user-places.xbel.bak"
    ];
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
