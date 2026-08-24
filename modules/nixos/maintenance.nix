{
  config,
  lib,
  pkgs,
  ...
}:
let
  maintenanceLock = "/run/lock/nix-store-maintenance.lock";
  flock = lib.getExe' pkgs.util-linux "flock";
  nixCollectGarbage = "${config.nix.package.out}/bin/nix-collect-garbage";
  nixStore = lib.getExe' config.nix.package "nix-store";
in
{
  nix = {
    gc = {
      automatic = true;
      dates = "Sun 03:00";
      options = "--delete-older-than 14d";
      persistent = true;
      randomizedDelaySec = "30min";
    };

    optimise = {
      automatic = true;
      dates = "Sun 05:00";
      persistent = true;
      randomizedDelaySec = "30min";
    };
  };

  # Persistent timers can both be caught up after boot. The shared flock
  # serializes GC and store optimisation so they never compete for the store.
  systemd.services.nix-gc.script = lib.mkForce ''
    exec ${flock} --exclusive ${maintenanceLock} \
      ${nixCollectGarbage} ${config.nix.gc.options}
  '';

  systemd.services.nix-optimise = {
    # Prefer GC first when systemd happens to queue both jobs together.
    after = [ "nix-gc.service" ];

    serviceConfig.ExecStart = lib.mkForce
      "${flock} --exclusive ${maintenanceLock} ${nixStore} --optimise";
  };
}
