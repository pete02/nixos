{...}: {
  flake.nixosModules.rpi = {
    config,
    lib,
    pkgs,
    ...
  }: let
    # Features that must never be on for a Pi. Adjust to your real option paths.
    forbidden = [
      ["gaming" "enable"]
      ["desktop" "enable"]
    ];
  in {
    assertions =
      [
        {
          assertion = pkgs.stdenv.hostPlatform.isAarch64;
          message = "rpi host evaluated for ${pkgs.stdenv.hostPlatform.system}, expected aarch64";
        }
      ]
      ++ map (path: {
        assertion = !(lib.attrByPath path false config);
        message = "${lib.concatStringsSep "." path} is not allowed on rpi hosts";
      })
      forbidden;

    nix.settings.experimental-features = ["nix-command" "flakes"];

    zramSwap.enable = true;
    boot.supportedFilesystems.zfs = lib.mkForce false;
    boot.initrd.availableKernelModules = ["usb_storage" "uas" "xhci_pci" "ehci_hcd" "uhci_hcd"];
  };
}