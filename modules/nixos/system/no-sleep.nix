{ ... }:

{
  # sleep 系ターゲットを mask し、systemd 経路でのサスペンド/休止を一切禁止する。
  # logind の HandleLidSwitch=ignore 等だけでは DE やアプリからの明示的 suspend を
  # 塞げないため、ターゲット自体を無効化して起点を根絶する。
  systemd.targets = {
    sleep.enable = false;
    suspend.enable = false;
    hibernate.enable = false;
    hybrid-sleep.enable = false;
  };
}
