{ id, ssid, psk }:
{
  connection = {
    inherit id;
    type = "wifi";
  };
  wifi = {
    mode = "infrastructure";
    inherit ssid;
  };
  wifi-security = {
    key-mgmt = "wpa-psk";
    inherit psk;
  };
  ipv4.method = "auto";
  ipv6.method = "auto";
}
