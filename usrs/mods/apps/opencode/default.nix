{
  config,
  pkgs,
  ...
}: {
  services.ollama = {
    enable = true;
    # packages = pkgs.ollama-cuda; # Uncomment if your system needs the CUDA-compiled package specifically
    environmentVariables = {
      OLLAMA_CONTEXT_LENGTH = "64000"; # Environment variables should be strings
      OLLAMA_FLASH_ATTENTION = "1";

      # Forces Ollama to wake up and utilize the NVIDIA GPU on your hybrid laptop
      __NV_PRIME_RENDER_OFFLOAD = "1";
      __NV_PRIME_RENDER_OFFLOAD_PROVIDER = "NVIDIA-G0";
      __GLX_VENDOR_LIBRARY_NAME = "nvidia";
      __VK_LAYER_NV_optimus = "NVIDIA_only";

      # Explicitly maps the host's OpenGL/CUDA driver binaries inside the service context
      LD_LIBRARY_PATH = "/run/opengl-driver/lib:/run/opengl-driver-32/lib";
    };
  };

  xdg.configFile."opencode/opencode.json".text = builtins.toJSON {
    "$schema" = "https://opencode.ai/config.json";

    # ─── DEFAULT ACTIVE MODEL ───
    model = "ollama/qwen3:1.7b";

    # ─── LOCAL PROVIDER DEFINITION ───
    provider = {
      ollama = {
        npm = "@ai-sdk/openai-compatible";
        name = "Ollama (Local)";
        options = {
          baseURL = "http://localhost:11434/v1";
        };
        models = {
          "qwen3:1.7b" = {
            tools = true;
          };
        };
      };
    };

    # ─── EXPLICITLY ALLOW LOCAL DIRECTORY DISCOVERY ───
    permission = {
      edit = "allow";
      bash = "ask";
      webfetch = "allow";
    };
  };
}
