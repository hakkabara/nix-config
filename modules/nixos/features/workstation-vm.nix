{
  config,
  lib,
  ...
}:

let
  cfg = config.hakkabara.workstationVm;
in
{
  options.hakkabara.workstationVm.enable = lib.mkEnableOption "always-on workstation VM policy";

  config = lib.mkIf cfg.enable {
    # -------------------------------------------------------------------------
    # Sleep states
    #
    # Workstation VMs must remain running. The Windows host controls physical
    # access and host power state; the guest must not independently suspend or
    # hibernate because of inactivity.
    # -------------------------------------------------------------------------

    systemd.sleep.settings.Sleep = {
      AllowSuspend = "no";
      AllowHibernation = "no";
      AllowHybridSleep = "no";
      AllowSuspendThenHibernate = "no";
    };

    # -------------------------------------------------------------------------
    # systemd-logind
    #
    # Ignore idle and hardware-style sleep events inside the VM.
    #
    # Lid events normally do not matter in a VMware guest, but explicitly
    # ignoring them makes the policy safe to reuse on workstation VMs where
    # such events might be exposed by the hypervisor.
    # -------------------------------------------------------------------------

    services.logind.settings.Login = {
      IdleAction = "ignore";

      HandleSuspendKey = "ignore";
      HandleHibernateKey = "ignore";

      HandleLidSwitch = "ignore";
      HandleLidSwitchExternalPower = "ignore";
      HandleLidSwitchDocked = "ignore";
    };
  };
}
