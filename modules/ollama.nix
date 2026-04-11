{ pkgs, ... }:
{
  home.packages = [ pkgs.ollama ];

  systemd.user.services.ollama = {
    Unit = {
      Description = "Ollama local LLM server";
      After = [ "network.target" ];
    };
    Service = {
      ExecStart = "${pkgs.ollama}/bin/ollama serve";
      Restart = "on-failure";
      RestartSec = 3;
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
