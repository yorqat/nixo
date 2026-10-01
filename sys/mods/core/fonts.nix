{pkgs, ...}: {
  fonts = {
    enableDefaultPackages = true;
    # Satoshi is not listed here: stylix.fonts.sansSerif already registers it,
    # and listing it twice only duplicated the store path. The nerd font below
    # is what actually renders eww's MDI glyphs -- Comic Mono has none of them.
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
