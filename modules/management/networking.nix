{ ... }:
{
  systemd.network.networks."10-wired" = {
    matchConfig.Name = "enp12s0"; # replace with your NIC name
    networkConfig.DHCP = "yes";
    dhcpConfig = {
      ClientIdentifier = "mac";
      UseDomains = "true";
      CriticalConnection = "true";
    };
  };
}
