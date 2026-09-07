{pkgs, ...}: {
  home.packages = with pkgs; [
    mpv
    yt-dlp
  ];
}
