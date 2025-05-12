{
  pkgs,
  lib,
  ...
}: {
  programs.firefox = {
    enable = true;
    package = pkgs.firefox-wayland;
    #profiles.default.extensions.packages = with pkgs.nur.repos.rycee.firefox-addons; [
      # ublock-origin
      #consent-o-matic
      #return-youtube-dislikes
      #adnauseam

      #refined-github
    #];
  };
}
