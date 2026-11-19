set -euo pipefail

report_error() {
  local status=$?
  printf 'Sound output command failed (status %s)\n' "$status" >&2
  notify-send -u critical "Sound output" "Audio switch failed; see the journal for details" || true
  exit "$status"
}

trap report_error ERR

fail() {
  printf 'Sound output: %s\n' "$1" >&2
  notify-send -u critical "Sound output" "$1"
  exit 1
}

select_sink() {
  local sink=$1 description inputs input
  description=$(pactl -f json list sinks | jq -er --arg sink "$sink" \
    '.[] | select(.name == $sink) | .description')
  pactl set-default-sink "$sink"
  inputs=$(pactl -f json list sink-inputs | jq -r '.[].index')
  while IFS= read -r input; do
    [ -n "$input" ] || continue
    pactl move-sink-input "$input" "$sink"
  done <<< "$inputs"
  notify-send "Sound output" "$description"
}

select_profile() {
  local card=$1 profile=$2 sink_name attempt sinks
  sink_name="alsa_output.${card#alsa_card.}.${profile#output:}"
  pactl set-card-profile "$card" "$profile"
  for ((attempt = 0; attempt < 20; attempt++)); do
    sinks=$(pactl -f json list sinks)
    if jq -e --arg sink "$sink_name" 'any(.[]; .name == $sink)' <<< "$sinks" > /dev/null; then
      select_sink "$sink_name"
      return
    fi
    sleep 0.5
  done
  fail "Audio output $sink_name did not appear"
}

case "${1:-}" in
  cycle|cycle-reverse)
    [ "$#" -eq 1 ] || fail "Usage: sound-output cycle | cycle-reverse"
    direction=1
    [ "$1" != "cycle-reverse" ] || direction=-1
    sinks=$(pactl -f json list sinks)
    cards=$(pactl -f json list cards)
    current=$(pactl get-default-sink)
    next=$(jq -en --argjson sinks "$sinks" --argjson cards "$cards" --arg current "$current" --argjson direction "$direction" '
      ([$sinks[] | . as $sink | select((.ports | length) == 0 or
        any(.ports[]; .name == $sink.active_port and .availability != "not available")) |
        {name: .name}] +
       [$cards[] | select(.name | startswith("alsa_card.")) | .name as $card |
        .ports[]? | select(.type == "HDMI" and .availability == "available") |
        .profiles[]? | select(test("^output:hdmi-stereo(-extra[0-9]+)?$")) |
        . as $profile | {
          name: ("alsa_output." + ($card | ltrimstr("alsa_card.")) + "." + ($profile | ltrimstr("output:"))),
          card: $card, profile: $profile
        }]) | unique_by(.name) | sort_by(.name)
      | if length == 0 then error("No available sound outputs")
        else (map(.name) | index($current)) as $index |
          if $index == null then
            if $direction == 1 then .[0] else .[-1] end
          else
            .[($index + $direction + length) % length]
          end
        end
    ')
    card=$(jq -r '.card // empty' <<< "$next")
    if [ -n "$card" ]; then
      profile=$(jq -r '.profile' <<< "$next")
      select_profile "$card" "$profile"
    else
      select_sink "$(jq -r '.name' <<< "$next")"
    fi
    ;;
  hdmi)
    [ "$#" -eq 3 ] || fail "Usage: sound-output hdmi CARD DISPLAY"
    card=$2
    display=$3
    profile=""
    for ((attempt = 0; attempt < 20; attempt++)); do
      cards=$(pactl -f json list cards)
      profile=$(jq -r --arg card "$card" --arg display "$display" '
        [.[] | select(.name == $card) | .ports[]? |
          select(.availability == "available" and .properties["device.product.name"] == $display) |
          .profiles[]? | select(test("^output:hdmi-stereo(-extra[0-9]+)?$"))] | first // empty
      ' <<< "$cards")
      [ -z "$profile" ] || break
      sleep 0.5
    done
    [ -n "$profile" ] || fail "HDMI audio for $display is not available"
    select_profile "$card" "$profile"
    ;;
  *)
    fail "Usage: sound-output cycle | cycle-reverse | hdmi CARD DISPLAY"
    ;;
esac
