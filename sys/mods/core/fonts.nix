{pkgs, ...}: {
  fonts = {
    enableDefaultFonts = true;
    fonts = with pkgs; [
      (nerdfonts.override {fonts = ["JetBrainsMono"];})
      #(nerdfonts.override {fonts = ["FiraCode"];})
      # font-awesome
      # emacs-all-the-icons-fonts
      inter
      comic-mono
      fira-code
    ];

    fontconfig = {
      defaultFonts = {
        sansSerif = ["Inter"];
        monospace = ["JetBrainsMono Nerd Font"];
      };
    };
  };
}
