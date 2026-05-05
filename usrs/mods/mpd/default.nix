{pkgs, ...}: {
  services.mpd = {
    enable = true;
    musicDirectory = "~/Music";
    extraConfig = ''
      audio_output {
          type    "pipewire"
          name    "Pipewire Sound Server"
      }
    '';
  };

  home.packages = [
    pkgs.mpc
    pkgs.ncmpcpp
  ];
}
