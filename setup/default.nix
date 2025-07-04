# TODO: turn this to a function
let 
    includes = {
        kubernetes = false;
        virt-manager = true;
        libreoffice = false;
        minecraftPrismLauncher = true;
        steam = false;
    };

    extraPackages = [
        "signal-desktop"
        "discord-canary"
        "aseprite"
    ];

    userName = "yor";
    hostName = "qat";

    userWebsite = "https://yorqat.com/";

    homeDir = "/home/${userName}";

    # I use mountpoints /dat for my media and /cred for my secrets
    symLinks = [
        # [ "dest" "src" ]
        ["${homeDir}/Documents" "/dat/Documents"]
        ["${homeDir}/Downloads" "/dat/Downloads"]
        ["${homeDir}/Videos" "/dat/Videos"]
        ["${homeDir}/Pictures" "/dat/Pictures"]
        ["${homeDir}/Music" "/dat/Music"]
        ["${homeDir}/.ssh" "/cred/.ssh"]
        ["${homeDir}/.wakatime.cfg" "/cred/.wakatime.cfg"]

        ["${homeDir}/my-nixos" "/dat/Documents/my-nixos" ]
    ];

    timeZone = "Asia/Manila";

    defaultLocale = "en_PH.UTF-8";
    extraLocale = "fil_PH";
in {
    inherit userName;
    inherit hostName;
    inherit homeDir;
    inherit symLinks;
    inherit timeZone;
    inherit defaultLocale;
    inherit extraLocale;
    inherit includes;

    # This section are step by step instructions
    # for enabling secure boot
    # https://nixos.wiki/wiki/Secure_Boot
    secureBoot = {
        bootspec = false;
        lanzaboote = false;
    };

    # This value determines the NixOS release from which the default
    # settings for stateful data, like file locations and database versions
    # on your system were taken.

    # It‘s perfectly fine and recommended to leave
    # this value at the release version of the first install of this system.
    # Before changing this value read the documentation for this option
    # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
    stateVersion = "24.05"; # TLDR; only change on fresh install
}
