{
  pkgs,
  lib,
  ...
}: {
  programs.chromium = {
    enable = true;
  };

  programs.firefox = {
    enable = true;
    package = pkgs.firefox-devedition;

    # not working atm
    #profiles = {
      #default = {
      #};
    #};
  };
}
