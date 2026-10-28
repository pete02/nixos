# Shared knobs for the installer targets (not your fleet hosts).
{
  username = "pete";
  initialPassword = "Oma2026#rpi";   # change me
  sshKeys = [
    # "ssh-ed25519 AAAA... you@laptop"
  ];
  timeZone = "UTC";
  locale = "en_US.UTF-8";
  stateVersion = "25.11";
}
