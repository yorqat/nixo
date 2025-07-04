{pkgs, ...}: {
  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [
      nerd-fonts.droid-sans-mono
      inter
      comic-mono
      comic-neue
      fira-code
    ];

    fontconfig = {
      defaultFonts = {
        sansSerif = ["Comic Neue"];
        monospace = ["Comic Mono" "DroidSansMono Nerd Font"];
      };
    };
  };
}
