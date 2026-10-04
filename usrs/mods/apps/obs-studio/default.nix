{pkgs, ...}: {
  programs.obs-studio = {
    enable = false;
    plugins = with pkgs.obs-studio-plugins; [
      obs-shaderfilter
      obs-source-clone
      obs-move-transition
      obs-vertical-canvas
    ];
  };
}
