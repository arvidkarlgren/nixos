#!/usr/bin/env bash
set -euo pipefail

if (( $# != 1 )); then
  printf 'Usage: %s {desk|tv}\n' "$0" >&2
  exit 1
fi

case "$1" in
  desk)
    exec kscreen-doctor \
      output.DP-1.enable \
      output.DP-1.mode.2560x1440@165 \
      output.DP-1.rotation.none \
      output.DP-1.scale.1 \
      output.DP-1.position.1080,0 \
      output.DP-1.vrrpolicy.automatic \
      output.DP-1.primary \
      output.DP-2.enable \
      output.DP-2.mode.1920x1080@144 \
      output.DP-2.rotation.left \
      output.DP-2.scale.1 \
      output.DP-2.position.0,0 \
      output.DP-2.vrrpolicy.never \
      output.HDMI-A-1.disable
    ;;
  tv)
    kscreen-doctor \
      output.HDMI-A-1.enable \
      output.HDMI-A-1.mode.3840x2160@60 \
      output.HDMI-A-1.rotation.none \
      output.HDMI-A-1.position.0,0 \
      output.HDMI-A-1.vrrpolicy.never \
      output.HDMI-A-1.primary \
      output.DP-1.disable \
      output.DP-2.disable
    exec sound-output hdmi alsa_card.pci-0000_08_00.1 "LG TV"
    ;;
  *)
    printf 'Unknown display mode: %s\nUsage: %s {desk|tv}\n' "$1" "$0" >&2
    exit 1
    ;;
esac
