{pkgs, ...}: {
  programs.obs-studio = {
    enable = true;
    plugins = with pkgs.obs-studio-plugins; [
      obs-shaderfilter
      obs-source-clone
      obs-move-transition
      obs-vertical-canvas
    ];
  };
}
