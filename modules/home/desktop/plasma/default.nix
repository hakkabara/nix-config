{
  config,
  lib,
  plasma-manager,
  ...
}:

let
  cfg = config.hakkabara.desktop.plasma;

  # Plasma has separate AC/battery/low-battery profiles.
  # For an always-on VM they should all behave identically.
  alwaysOnPowerProfile = {
    autoSuspend.action = "nothing";

    turnOffDisplay.idleTimeout = "never";

    dimDisplay.enable = false;
  };
in
{
  # plasma-manager provides the programs.plasma.* options used below.
  imports = [
    plasma-manager.homeModules.plasma-manager
  ];

  options.hakkabara.desktop.plasma = {
    enable = lib.mkEnableOption "managed KDE Plasma user configuration";

    # Deliberately OFF by default.
    #
    # Enabling Plasma must never implicitly mean that a machine no longer
    # locks its screen or saves power.
    alwaysOn.enable = lib.mkEnableOption "always-on Plasma desktop policy";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        programs.plasma.enable = true;
      }

      (lib.mkIf cfg.alwaysOn.enable {
        programs.plasma = {
          # Manual locking is still possible. We only disable automatic
          # locking and lock-on-resume/startup.
          kscreenlocker = {
            autoLock = false;
            lockOnResume = false;
            lockOnStartup = false;
          };

          # Prevent Plasma/PowerDevil from dimming, switching the display off,
          # or requesting automatic suspend.
          powerdevil = {
            AC = alwaysOnPowerProfile;
            battery = alwaysOnPowerProfile;
            lowBattery = alwaysOnPowerProfile;
          };
        };
      })
    ]
  );
}
