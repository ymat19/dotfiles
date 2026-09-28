{ inputs, ... }:
{
  # home.nix
  imports = [
    inputs.zen-browser.homeModules.beta
    # or inputs.zen-browser.homeModules.twilight
    # or inputs.zen-browser.homeModules.twilight-official
  ];

  programs.zen-browser = {
    enable = true;
    policies = {
      DisableAppUpdate = true;
      DisableTelemetry = true;
      # find more options here: https://mozilla.github.io/policy-templates/
      Preferences = {
        # Zen 独自の zen.tab-unloader は設定 UI に残るだけで実装が消えているため、
        # Firefox 本体の TabUnloader を使う。Linux ではこれが既定で無効
        "browser.tabs.unloadOnLowMemory" = {
          Value = true;
          Status = "default";
        };
        # 既定の 5% では zram が満杯になって固まり始めてから発火するため、早めに発火させる
        "browser.low_commit_space_threshold_percent" = {
          Value = 15;
          Status = "default";
        };
      };
    };
  };
}
