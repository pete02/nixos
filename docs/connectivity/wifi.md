# WiFi — `connectivity-wifi`

`modules/features/connectivity/wifi.nix`. Wireless via NetworkManager, with
the pre-shared key kept in sops so it never lands in the Nix store.

## Options

- `connectivity.wifi.enable` — wireless via NetworkManager.
- `connectivity.wifi.Ssid` (`nullOr str`, default `null`) — the SSID to
  autoconnect to on boot.

## What it sets, and why

- `networking.networkmanager.enable = lib.mkForce true` — `mkForce` overrides
  nixpkgs' autodetection so NM is on regardless of what the generator
  detected.
- `wifi.backend = "wpa_supplicant"` — use `wpa_supplicant` as the supplicant
  (the fleet's router is a known WPA2 target; explicit backend avoids the
  autodetect picking the wrong one).
- `systemd.services.NetworkManager-wait-online.enable = false` — don't block
  boot on "network online"; a wireless host that boots before its wireless
  comes up still works, unlike wired hosts which use `CriticalConnection`.
- user `extraGroups = ["networkmanager"]`.

## The PSK stays out of the store

- `sops.secrets."wifi/psk" = {};` — the key lives only in the encrypted
  file (see [secrets](../secrets.md)).
- A template unit `wifi-env` has content `WIFI_PSK=${config.sops.placeholder."wifi/psk"}`
  — the placeholder string, so the store path contains no secret.
- `ensureProfiles.environmentFiles = [wifi-env's path]` — NetworkManager's
  profile is told to source that environment file at activation, which is
  where the real PSK is substituted.
- The profile itself is `lib.mkIf (Ssid != null)` — no profile until an SSID
  is actually configured. The `home-wifi` connection:
  `type wifi`, `autoconnect true`, `wifi.mode = "infrastructure"`,
  `wifi.ssid = Ssid`, `wifi-security.key-mgmt = "wpa-psk"`,
  `psk = "$WIFI_PSK"` (substituted from the environment file), and
  `ipv4/ipv6 method = "auto"`.

So the secret's path is: sops file → decrypted env file → NM profile, never
through the store. `infrastructure` mode means a pre-shared key (PSK) rather
than a passphrase that gets run through KDF at connect time — the fleet knows
the router's PSK up front.
