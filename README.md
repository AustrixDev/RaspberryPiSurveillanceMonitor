# RaspberryPiSurveillanceMonitor

Zeigt vier Kamera-Streams eines Reolink NVR (RLN8-410E) als 2x2-Raster auf einem 1080p-Fernseher an – mit einem Raspberry Pi 5 und Raspberry Pi OS Desktop.

## Funktionsweise
- Pro Kamera ein eigener `mpv`-Prozess als randloses Fenster auf einem Viertel des Bildschirms.
- Fällt eine Kamera oder Verbindung aus, startet nur dieser Prozess neu (alle 5 s); die anderen Kacheln laufen weiter.
- Streams per RTSP über TCP, standardmäßig **Substreams** (der Pi 5 hat keinen H.264-Hardware-Decoder; Substreams kosten kaum CPU).
- Start automatisch nach dem Desktop-Login, Log unter `~/.cache/surveillance-monitor.log`.

## Voraussetzungen
- Raspberry Pi OS **Desktop** (Bookworm), Desktop-Sitzung unter **X11**. Unter Wayland lassen sich Fenster nicht positionieren; `install.sh` bietet die Umstellung an (entspricht `raspi-config` → Advanced Options → Wayland → X11).
- Am NVR: RTSP aktiv (*Einstellungen → Netzwerk → Erweitert → Servereinstellungen*, Port 554) und am besten ein eigener Benutzer nur mit Live-Ansicht-Rechten.

## Installation
```bash
git clone <repo-url> ~/RaspberryPiSurveillanceMonitor
cd ~/RaspberryPiSurveillanceMonitor
./install.sh
nano ~/.config/surveillance-monitor.env   # NVR-IP, Benutzer, Passwort
sudo reboot
```

`install.sh` installiert `mpv` und `ffmpeg`, kopiert das Skript nach `~/.local/bin/surveillance-monitor`, legt die Konfiguration und einen Autostart-Eintrag an, schaltet das Bildschirm-Blanking ab und aktiviert die automatische Desktop-Anmeldung.

## Konfiguration (`~/.config/surveillance-monitor.env`)
| Variable | Standard | Bedeutung |
|---|---|---|
| `NVR_HOST`, `NVR_USER`, `NVR_PASS` | – | Zugangsdaten des NVR |
| `CHANNELS` | `1 2 3 4` | Kanäle (= PoE-Ports), Reihenfolge oben-links, oben-rechts, unten-links, unten-rechts |
| `STREAM` | `sub` | `sub` oder `main` |
| `CODEC` | `h264` | Präfix der Reolink-URL (`h264Preview_…` / `h265Preview_…`) |
| `SCREEN_W`, `SCREEN_H` | `1920`, `1080` | Auflösung des Fernsehers |

Sonderzeichen im Passwort werden URL-kodiert; im Zweifel ein Passwort nur aus Buchstaben und Ziffern verwenden.

## Fehlersuche
- Einzelnen Stream testen: `mpv --rtsp-transport=tcp rtsp://USER:PASS@NVR_IP:554/h264Preview_01_sub`
- Codec/Auflösung prüfen: `ffprobe -rtsp_transport tcp -v error -select_streams v:0 -show_entries stream=codec_name,width,height -of csv=p=0 "rtsp://USER:PASS@NVR_IP:554/h264Preview_01_sub"`
- Beenden: `pkill -f surveillance-monitor; pkill mpv`
