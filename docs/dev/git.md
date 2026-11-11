# Dev git — `dev-git`

`modules/features/dev/git.nix`. Git client plus ssh identities for the fleet's
two forge hosts.

## Options

- `dev.git` — enable the git client.

## What it sets, and why

- installs `pkgs.git`.
- pulls two sops secrets, owned by the user (so ssh can read them):
  `services/github` and `services/forgejo`. These are the private-key files
  used to authenticate to each forge.
- writes `/etc/ssh/ssh_config` with two `Host` blocks that map each forge to
  its secret identity:
  - `Host github.com` → `identityFile /run/secrets/services/github`, user
    `git`.
  - `Host git.lumilukko.com` → port `2222`, user `git`,
    `identityFile /run/secrets/services/forgejo`.
  This is why the fleet can `git clone` over ssh without any per-repo config —
  the identity is resolved by hostname from one central ssh_config.
- `programs.ssh.knownHosts."git.lumilukko.com"` pins the Forgejo host key
  (an ed25519 public key — not a secret). The
  `hostNames = ["[git.lumilukko.com]:2222"]` uses the **bracketed
  `host:port` form** ssh requires for non-port-22 hosts, matching the comment
  `# from: ssh-keyscan -p 2222 -t ed25519 git.lumilukko.com` — the key was
  captured against port 2222, so it must be keyed the same way or ssh would
  look it up under the wrong name.

## Why the design

Forgejo lives on a non-standard ssh port (2222), which is the whole reason for
the bracketed knownHosts entry and the explicit `Port 2222`. Keeping both
forges' identities in ssh_config (rather than per-remote URLs) means a
repository URL never has to embed a key path — the secret stays in `/run/secrets`
and ssh picks it by host.
