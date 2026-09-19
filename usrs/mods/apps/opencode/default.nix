{
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
