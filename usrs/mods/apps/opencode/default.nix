{
  xdg.configFile."opencode/opencode.json".text = builtins.toJSON {
    "$schema" = "https://opencode.ai/config.json";
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
    model = "ollama/qwen3:1.7b";
  };
}
