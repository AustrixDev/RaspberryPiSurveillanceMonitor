#!/usr/bin/env bash
# Zeigt 4 RTSP-Streams eines Reolink NVR als 2x2-Raster auf dem Bildschirm.
# Pro Kamera ein eigener mpv-Prozess mit eigener Neustart-Schleife: fällt eine
# Kamera aus, bleibt nur ihre Kachel schwarz, die anderen laufen weiter.
set -uo pipefail

CONFIG="${MONITOR_CONFIG:-$HOME/.config/surveillance-monitor.env}"
if [ -f "$CONFIG" ]; then
  # shellcheck disable=SC1090
  . "$CONFIG"
fi

: "${NVR_HOST:?NVR_HOST fehlt in $CONFIG}"
: "${NVR_USER:?NVR_USER fehlt in $CONFIG}"
: "${NVR_PASS:?NVR_PASS fehlt in $CONFIG}"
NVR_PORT="${NVR_PORT:-554}"
CHANNELS="${CHANNELS:-1 2 3 4}"   # Reihenfolge: oben-links, oben-rechts, unten-links, unten-rechts
STREAM="${STREAM:-sub}"           # sub (empfohlen) | main
CODEC="${CODEC:-h264}"            # Pfad-Präfix der Reolink-URL: h264 | h265
SCREEN_W="${SCREEN_W:-1920}"
SCREEN_H="${SCREEN_H:-1080}"
RETRY_DELAY="${RETRY_DELAY:-5}"
LOG_FILE="${LOG_FILE:-$HOME/.cache/surveillance-monitor.log}"

read -r -a CH <<< "$CHANNELS"
if [ "${#CH[@]}" -ne 4 ]; then
  echo "CHANNELS braucht genau 4 Kanäle (ist: '$CHANNELS')" >&2
  exit 1
fi

# Ohne Terminal (Autostart) in eine Logdatei schreiben.
if [ ! -t 1 ]; then
  mkdir -p "$(dirname "$LOG_FILE")"
  exec >>"$LOG_FILE" 2>&1
fi

log() { printf '%s %s\n' "$(date '+%F %T')" "$*"; }

# Sonderzeichen in Benutzer/Passwort (@ : / # ...) würden die URL zerbrechen.
urlencode() {
  local LC_ALL=C s="$1" out="" c i
  for ((i = 0; i < ${#s}; i++)); do
    c="${s:i:1}"
    case "$c" in
      [a-zA-Z0-9._~-]) out+="$c" ;;
      *) printf -v c '%%%02X' "'$c"; out+="$c" ;;
    esac
  done
  printf '%s' "$out"
}

AUTH="$(urlencode "$NVR_USER"):$(urlencode "$NVR_PASS")"
url() { printf 'rtsp://%s@%s:%s/%sPreview_%02d_%s' "$AUTH" "$NVR_HOST" "$NVR_PORT" "$CODEC" "$1" "$STREAM"; }

TILE_W=$((SCREEN_W / 2))
TILE_H=$((SCREEN_H / 2))

run_camera() {
  local ch="$1" x="$2" y="$3"
  while true; do
    log "Kanal $ch: verbinde"
    mpv --no-config \
        --title="Kamera $ch" \
        --geometry="${TILE_W}x${TILE_H}+${x}+${y}" \
        --no-border --ontop --keepaspect-window=no \
        --no-osc --osd-level=0 --no-input-default-bindings --cursor-autohide=always \
        --no-audio --profile=low-latency --cache=no --framedrop=vo \
        --hwdec=auto-safe \
        --demuxer-lavf-o=rtsp_transport=tcp \
        --network-timeout=10 \
        --msg-level=all=error \
        "$(url "$ch")"
    log "Kanal $ch: mpv beendet (Code $?), neuer Versuch in ${RETRY_DELAY}s"
    sleep "$RETRY_DELAY"
  done
}

# Beim Beenden alle Kamera-Prozesse mitnehmen.
trap 'trap - INT TERM EXIT; kill 0' INT TERM EXIT

log "Start: $NVR_HOST, Kanäle ${CH[*]}, Stream $STREAM, ${SCREEN_W}x${SCREEN_H}"
run_camera "${CH[0]}" 0        0        &
run_camera "${CH[1]}" "$TILE_W" 0        &
run_camera "${CH[2]}" 0        "$TILE_H" &
run_camera "${CH[3]}" "$TILE_W" "$TILE_H" &
wait
