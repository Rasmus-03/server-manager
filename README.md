# Server Manager

Cross-platform server management for Minecraft, CS2, ARK, and custom game servers.

- **macOS**: Native SwiftUI app
- **Linux / Any OS**: Web UI (Node.js)

## Features

- **Multi-server** — Manage multiple servers from one interface
- **One-click setup** — Download Vanilla or Paper servers directly
- **SteamCMD integration** — Install Counter-Strike 2 and ARK dedicated servers (Linux/macOS)
- **Playit tunnel** — Expose your server online via playit.gg
- **Resource monitoring** — Real-time CPU/RAM usage per server
- **Auto-restart** — Automatic crash detection and recovery
- **Auto-scaling** — Dynamic RAM allocation based on usage
- **Backups** — Scheduled world backups with rotation

## Requirements

### macOS Native App
- macOS 14.0+ (Sonoma)
- Swift 5.9+ (Xcode 15+ or command-line tools)

### Web UI (all platforms including Linux)
- Node.js 18+
- Java 17+ (for Minecraft servers)

### Optional
- [playit.gg](https://playit.gg) — `brew install playit` (macOS) or `apt install playit` (Linux)
- [SteamCMD](https://developer.valvesoftware.com/wiki/SteamCMD) — for CS2/ARK servers
- Java 17+ — `brew install openjdk@17` (macOS) or `apt install openjdk-17-jre-headless` (Linux)

## Build & Run

### macOS Native App
```bash
./build.sh
```
Installs to `/Applications/Server Manager.app`.

### Web UI (Linux / macOS)
```bash
cd src/web
npm install
node server.js
```
Open http://localhost:3478 in your browser.

## Project Structure

```
src/
  App.swift              # SwiftUI app entry point (macOS only)
  ServerManager.swift    # Core server management logic (macOS only)
  ContentView.swift      # SwiftUI views (macOS only)
  web/
    server.js            # Express server (cross-platform)
    package.json         # Node.js dependencies
    public/
      index.html         # Web UI frontend
Resources/
  AppIcon.icns           # App icon
build.sh                 # Build script for macOS + web
```

## License

MIT
