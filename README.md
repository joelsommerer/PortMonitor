# PortMonitor

Eine schlanke macOS-Menüleisten-App, die zeigt, welche TCP-Ports lokal belegt sind und von welchem Prozess. Per Klick lässt sich der jeweilige Prozess beenden — ideal um schnell zu sehen, ob z. B. Port `3000`, `5173` oder `8080` schon von einem Dev-Server blockiert ist, und den Blocker direkt zu stoppen.

![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/license-MIT-green)

## Features

- 🔍 **Live-Übersicht** aller belegten TCP-Ports (Auto-Refresh alle 3 s)
- 🏷️ **Dev-Port-Filter** — typische Ports (3000, 4200, 5173, 8000, 8080, …) sind markiert und standardmäßig gefiltert
- 🛑 **Prozess stoppen** direkt aus der UI (SIGTERM mit SIGKILL-Fallback nach 2 s)
- 🎯 **Menüleisten-only** — kein Dock-Icon, minimaler Fußabdruck
- 🇩🇪 Deutsche Oberfläche

## Installation

### Variante A: DMG (empfohlen)

1. Lade die aktuelle `PortMonitor-x.y.z.dmg` aus dem [Releases-Tab](../../releases/latest) herunter.
2. Öffne das DMG und ziehe `PortMonitor.app` in deinen `Applications`-Ordner.
3. Starte die App. Da sie ad-hoc-signiert ist, beim ersten Start: Rechtsklick auf die App → **Öffnen** → **Öffnen**.

### Variante B: Selbst bauen

Voraussetzungen: macOS 13+ und Xcode Command-Line-Tools (`xcode-select --install`).

```bash
git clone https://github.com/joelsommerer/PortMonitor.git
cd PortMonitor
./build-app.sh
open PortMonitor.app
```

Optional ein DMG erzeugen (benötigt `create-dmg` via Homebrew):

```bash
brew install create-dmg
./build-dmg.sh
```

## Verwendung

Nach dem Start erscheint ein Netzwerk-Symbol in der Menüleiste. Klick darauf öffnet das Popover:

- **Toggle „Alle"** — schaltet zwischen Dev-Port-Filter und vollständiger Liste um.
- **Refresh-Button** — manuell aktualisieren (passiert sonst automatisch alle 3 s).
- **Stop-Button** pro Eintrag — sendet `SIGTERM`, nach 2 s `SIGKILL`, falls der Prozess noch lebt.

### Autostart beim Login

Systemeinstellungen → **Allgemein** → **Anmeldeobjekte** → `+` → `PortMonitor.app` auswählen.

Oder per Terminal:

```bash
osascript -e 'tell application "System Events" to make login item at end with properties {path:"/Applications/PortMonitor.app", hidden:false}'
```

## Wie es funktioniert

PortMonitor ruft `lsof -nP -iTCP -sTCP:LISTEN -F` auf und parst die Ausgabe. Es werden nur lauschende TCP-Sockets angezeigt. Prozesse anderer Benutzer erscheinen nur, wenn die App entsprechend ausgeführt wird (im Normalfall nicht relevant).

Standardmäßig gefilterte Dev-Ports:

```
3000, 3001, 3030, 3333,
4000, 4200, 4321,
5000, 5001, 5173, 5174, 5273, 5500,
8000, 8001, 8080, 8081, 8888,
9000, 9001, 9090, 9229,
27017 (Mongo), 5432 (Postgres), 3306 (MySQL), 6379 (Redis), 11434 (Ollama)
```

## Projektstruktur

```
PortMonitor/
├── Package.swift
├── build-app.sh              # baut .app-Bundle
├── build-dmg.sh              # baut DMG-Installer
└── Sources/PortMonitor/
    ├── main.swift            # Entry-Point
    ├── AppDelegate.swift     # Menüleisten-Item + Popover
    ├── PortScanner.swift     # lsof-Wrapper + Signal-Handling
    └── ContentView.swift     # SwiftUI-UI
```

## Lizenz

MIT — siehe [LICENSE](LICENSE).
