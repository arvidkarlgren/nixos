{ ... }:
{
  disko.devices.disk.main = {
    type = "disk";
    device = "/dev/disk/by-id/REPLACE_WITH_YOUR_DISK_ID";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          priority = 1;
          name = "ESP";
          size = "1G";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };
        root = {
          priority = 2;
          name = "root";
          size = "100%";
          content = {
            type = "btrfs";
            extraArgs = [ "-f" ];
            subvolumes = {
              "/@" = { mountpoint = "/"; mountOptions = [ "compress=zstd" "noatime" ]; };
              "/@home" = { mountpoint = "/home"; mountOptions = [ "compress=zstd" "noatime" ]; };
              "/@nix" = { mountpoint = "/nix"; mountOptions = [ "compress=zstd" "noatime" ]; };
              "/@log" = { mountpoint = "/var/log"; mountOptions = [ "compress=zstd" "noatime" ]; };
              "/@snapshots" = { mountpoint = "/.snapshots"; mountOptions = [ "compress=zstd" "noatime" ]; };
              "/@swap" = { mountpoint = "/.swapvol"; mountOptions = [ "noatime" ]; };
            };
          };
        };
      };
    };
  };
}
