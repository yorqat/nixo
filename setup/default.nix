# TODO: turn this to a function
let 
    includes = {
        kubernetes = true;
        docker = true;
        virt-manager = true;
        libreoffice = true;
        minecraftPrismLauncher = true;
        steam = true;
    };

    extraPackages = [
        "signal-desktop"
        "discord-canary"
    ];

    userName = "yor";
    hostName = "qat";

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
}