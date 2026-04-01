{ ... }:
{
  services.ollama = {
    enable = true;
    loadModels = [ "gemma3:4b" ];
  };
}
