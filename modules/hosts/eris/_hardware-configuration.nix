{...}:{
  fileSystems."/data" = {
    device = "/dev/disk/by-label/NIXOS_HDD";
    fsType = "ext4";
    options = ["nofail" "x-systemd.automount" "x-systemd.device-timeout=120"];
  };
}