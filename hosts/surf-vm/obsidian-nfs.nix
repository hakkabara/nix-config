{ config, ... }:

let
  # Interim transport: the "deployment" VMware network (ens33). Move to
  # VMnet4 (ens39) later by changing these two values and the WorkVM mount.
  interface = "ens33";
  client = config.hakkabara.networking.deploymentLan.hosts.work-vm.address;

  user = config.users.users.hakkabara;
  vault = "${user.home}/Obsidian";
in
{
  # Obsidian vault, synced on the SurfVM (LiveSync while the app runs) and
  # exported read-write to the WorkVM only. all_squash maps every client
  # request to the vault owner, so a root process on the WorkVM cannot act
  # as another SurfVM user.
  systemd.tmpfiles.rules = [
    "d ${vault} 0700 ${user.name} ${user.group} -"
  ];

  services.nfs = {
    server = {
      enable = true;
      exports = ''
        ${vault} ${client}(rw,sync,no_subtree_check,all_squash,anonuid=${toString user.uid},anongid=${
          toString config.users.groups.${user.group}.gid
        })
      '';
    };

    # NFSv4.2 only: no rpcbind/mountd needed by the client, one TCP port.
    settings.nfsd = {
      vers3 = false;
      "vers4.0" = false;
      "vers4.1" = false;
      "vers4.2" = true;
    };
  };

  networking.firewall.interfaces.${interface}.allowedTCPPorts = [ 2049 ];
}
