{
  config,
  pkgs,
  ...
}: {
  services.ollama = {
    enable = true;
    # packages = pkgs.ollama-cuda;
    environmentVariables = {
      OLLAMA_CONTEXT_LENGTH = "64000";
      OLLAMA_FLASH_ATTENTION = "1";

      __NV_PRIME_RENDER_OFFLOAD = "1";
      __NV_PRIME_RENDER_OFFLOAD_PROVIDER = "NVIDIA-G0";
      __GLX_VENDOR_LIBRARY_NAME = "nvidia";
      __VK_LAYER_NV_optimus = "NVIDIA_only";

      LD_LIBRARY_PATH = "/run/opengl-driver/lib:/run/opengl-driver-32/lib";
    };
  };

  xdg.configFile."opencode/opencode.json".text = builtins.toJSON {
    "$schema" = "https://opencode.ai/config.json";

    # ─── DEFAULT ACTIVE MODEL ───
    model = "ollama/gemma3:4b";

    # ─── LOCAL PROVIDERS DEFINITION ───
    # Changed from 'provider' to 'providers'
    provider = {
      ollama = {
        npm = "@ai-sdk/openai-compatible";
        name = "Ollama (Local)";
        options = {
          baseURL = "http://localhost:11434/v1";
        };
        models = {
          "gemma3:4b" = {};
          "lukaspetrik/gemma3-tools:4b" = {
            tools = true;
          };
          "qwen3:1.7b" = {
            tools = true;
          };
        };
      };

      opencode-zen-free = {
        npm = "@ai-sdk/openai-compatible";
        name = "OpenCode Zen (Free)";
        options = {
          baseURL = "https://opencode.ai/zen/v1";
        };
        models = {
          "jev-1.13-free" = {
            tools = true;
          };
          "mimo-v2.5-free" = {
            tools = true;
          };
          "ling-3.0-flash-fin-free" = {
            tools = true;
          };
          "nemotron-3-ultra-free" = {
            tools = true;
          };
          "muse-spark-1.3-contributor-free" = {
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
