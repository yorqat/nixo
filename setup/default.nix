let 
    preIncludes = {
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
in {
    userName = "yor";
    hostName = "qat";

    symLinks = [];

    timeZone = "Asia/Manila";

    defaultLocale = "en_PH.UTF-8";
    extraLocale = "fil_PH";

    includes = preIncludes;
}