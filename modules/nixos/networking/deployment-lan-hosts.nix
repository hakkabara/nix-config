# Single source of truth for addresses on the isolated deployment LAN.
#
# Every host with hakkabara.networking.deploymentLan enabled resolves these
# names through /etc/hosts, so no DNS server is needed and lookups keep
# working offline. Each host also takes its own static address from here.
{
  deploy-vm = {
    address = "192.168.245.10";

    # Service names, so clients never depend on which VM hosts a service.
    aliases = [
      "git"
      "cache"
    ];
  };

  work-vm.address = "192.168.245.11";

  surf-vm.address = "192.168.245.12";
}
