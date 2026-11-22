#!/usr/bin/env bash
# Installation auf Raspberry Pi OS Desktop (Bookworm), als normaler Benutzer ausführen.
set -euo pipefail
cd "$(dirname "$0")"

CONF="$HOME/.config/surveillance-monitor.env"

echo "==> Pakete installieren"
sudo apt update
sudo apt install -y mpv ffmpeg

echo "==> Skript nach ~/.local/bin"
install -D -m 755 bin/surveillance-monitor.sh "$HOME/.local/bin/surveillance-monitor"

echo "==> Konfiguration"
if [ ! -f "$CONF" ]; then
  install -D -m 600 config/surveillance-monitor.env.example "$CONF"
  echo "    $CONF angelegt – bitte NVR-Daten eintragen."
else
  echo "    $CONF existiert bereits, bleibt unverändert."
fi

echo "==> Autostart beim Desktop-Login"
mkdir -p "$HOME/.config/autostart"
cat > "$HOME/.config/autostart/surveillance-monitor.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Surveillance Monitor
Exec=$HOME/.local/bin/surveillance-monitor
X-GNOME-Autostart-enabled=true
EOF

echo "==> Bildschirmschoner/Blanking deaktivieren"
sudo raspi-config nonint do_blanking 1

echo "==> Automatische Anmeldung am Desktop"
sudo raspi-config nonint do_boot_behaviour B4

if [ "${XDG_SESSION_TYPE:-}" = "wayland" ] || [ -n "${WAYLAND_DISPLAY:-}" ]; then
  echo
  echo "Achtung: Der Desktop läuft unter Wayland. Dort können Fenster nicht"
  echo "positioniert werden, das 2x2-Raster braucht X11."
  read -r -p "Jetzt auf X11 umstellen? [J/n] " ans
  if [[ ! "$ans" =~ ^[nN] ]]; then
    sudo raspi-config nonint do_wayland W1
  fi
fi

echo
echo "Fertig. Konfiguration prüfen ($CONF), dann neu starten: sudo reboot"
echo "Manueller Test: ~/.local/bin/surveillance-monitor   (Log: ~/.cache/surveillance-monitor.log)"
