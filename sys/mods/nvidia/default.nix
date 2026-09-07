{config, ...}: {
  # nvidia driver toggles (G-Sync/VRR off to avoid flicker)
  environment.variables = {
    __GL_GSYNC_ALLOWED = "0";
    __GL_VRR_ALLOWED = "0";
  };

  hardware = {
    graphics = {
      enable = true;
      # 32-bit vulkan/gl comes from the steam module
      # va-api (videoAcceleration) defaults to true
    };

    nvidia = {
      modesetting.enable = true;
      open = true;
      # preserve video memory across suspend/resume (wayland compositors)
      powerManagement.enable = true;
      package = config.boot.kernelPackages.nvidiaPackages.stable;
    };
  };

  services.xserver.videoDrivers = ["nvidia"];
}
