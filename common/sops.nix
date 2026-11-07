{ ... }:
{
  sops.defaultSopsFile = ../secrets/common.yaml;
  sops.age.keyFile = "/var/lib/sops-nix/key.txt";
  sops.secrets.wifi = {
    format = "yaml";
    key = "wifi";
  };
}
