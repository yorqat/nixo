{
  self,
  ... 
}: let
  configDir = "themes-assets";
  source = ./config;
in
{
  home.file."${configDir}" = {
    enable = true;
    inherit source;
    force = true;
    recursive = true;
  };
}
