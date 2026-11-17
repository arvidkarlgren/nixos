# Voron printer host

This host targets a Raspberry Pi 4 and provides Klipper, Moonraker, Mainsail,
USB webcam streaming, SSH, and NetworkManager. The SD image uses the
Raspberry Pi-compatible NixOS boot configuration.

## Install

Build the image from the repository root:

```sh
nix build .#nixosConfigurations.voron.config.system.build.sdImage
```

Before booting the image, place the age identity that decrypts
`secrets/common.yaml` at `/var/lib/sops-nix/key.txt` on the image's root
filesystem with permissions `0600`. Do not add the private key to this
repository or the image derivation. The system uses the existing `arvid`
account and its SOPS-managed password.

Flash the resulting image from `result/sd-image/` to a microSD card and boot
the Pi. Mainsail is available at `http://voron.local/` (or the Pi's IP
address). Ethernet uses DHCP; Wi-Fi can be configured with NetworkManager, for
example with `nmcli device wifi connect "SSID" password "PASSWORD"`.

## Printer and camera setup

Klipper's config is mutable so Mainsail can edit it. The generated starter
config has conservative CoreXY limits and the usual virtual-SD, pause/resume,
display-status, and object-exclusion sections. It does not contain the
printer-specific MCU, pin, thermistor, or motion configuration. Upload the
matching Voron `printer.cfg` through Mainsail before attempting to print.

The webcam service expects a USB UVC camera at `/dev/video0`; Mainsail reaches
its stream through the local Nginx proxy at `/webcam/`. If no USB webcam is
connected, disable `services.mjpg-streamer` and remove the `"webcam Printer"`
Moonraker setting in `default.nix`.

Moonraker trusts private IPv4 clients so the LAN UI works without a login.
Trusted clients receive full Moonraker API access, including the configured
system-control actions. Narrow
`services.moonraker.settings.authorization.trusted_clients` to your LAN subnet
if other devices share those private address ranges.
