{
  xdg.configFile."opencode/opencode.json".text = builtins.toJSON {
    "$schema" = "https://opencode.ai/config.json";
    provider = {
      openrouter = {
        models = {
          "z-ai/glm-5.3-flash" = {};
        };
      };
    };
    model = "openrouter/z-ai/glm-5.3-flash";
  };
}
