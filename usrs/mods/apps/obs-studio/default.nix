{pkgs, ...}: {
  programs.obs-studio = {
    enable = true;
    plugins = with pkgs.obs-studio-plugins; [
      obs-source-clone
      obs-vertical-canvas
      # unsupported or something
      # obs-move-transition
      # obs-shaderfilter
    ];
  };
}
