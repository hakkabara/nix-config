{
  config,
  lib,
  ...
}:

let
  cfg = config.hakkabara.laptop;
in
{
  options.hakkabara.laptop = {
    enable = lib.mkEnableOption "physical laptop power-management baseline";

    thunderbolt.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable boltd for Thunderbolt/USB4 device authorization.";
    };

    hibernate.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Allow hibernation.

        Keep this disabled until the host has a sufficiently large swap
        target and resume from encrypted Btrfs storage has been tested.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Let the physical machine manage its own power state.
    powerManagement.enable = true;

    # Thunderbolt/USB4 authorization.
    #
    # Ordinary USB-C functionality does not depend on boltd, but docks using
    # Thunderbolt security/authorization do.
    services.hardware.bolt.enable = cfg.thunderbolt.enable;

    # -----------------------------------------------------------------------
    # Sleep states
    #
    # Suspend is our initial laptop sleep mechanism.
    #
    # Hibernate, hybrid-sleep and suspend-then-hibernate stay disabled until
    # resume from LUKS/Btrfs and a sufficiently large swap target are proven
    # on the physical laptop.
    # -----------------------------------------------------------------------

    systemd.sleep.settings.Sleep = {
      AllowSuspend = "yes";

      AllowHibernation = if cfg.hibernate.enable then "yes" else "no";

      AllowHybridSleep = "no";
      AllowSuspendThenHibernate = "no";
    };

    # -----------------------------------------------------------------------
    # Lid / dock behavior
    #
    # Mobile:
    #   closing the lid suspends the laptop.
    #
    # Docked:
    #   closing the lid must NOT suspend it, because the laptop may be used
    #   with external displays, keyboard and mouse through the USB-C/TB dock.
    # -----------------------------------------------------------------------

    services.logind.settings.Login = {
      HandleLidSwitch = "suspend";
      HandleLidSwitchExternalPower = "suspend";
      HandleLidSwitchDocked = "ignore";

      HandleSuspendKey = "suspend";

      HandleHibernateKey = if cfg.hibernate.enable then "hibernate" else "ignore";
    };
  };
}
