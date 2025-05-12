{pkgs, ...}: {
  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [
      # nerdfonts.droid-sans-mono
      inter
      comic-mono
      fira-code
    ];

    fontconfig = {
      defaultFonts = {
        # sansSerif = ["Inter"];
        # monospace = ["DroidSansMono Nerd Font"];
      };
    };
  };
}
