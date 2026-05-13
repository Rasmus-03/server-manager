# Server Manager

A macOS native server management app for Minecraft and other game servers.

Built with SwiftUI — no Electron, no web UI, just native macOS.

## Features

- **Multi-server** — Manage multiple Minecraft, CS2, ARK servers from one app
- **One-click setup** — Download Vanilla, Forge, or Paper servers directly
- **Mod management** — Browse, install, enable/disable Minecraft mods via Modrinth
- **SteamCMD integration** — Install Counter-Strike 2 and ARK dedicated servers
- **Playit tunnel** — Built-in tunnel support for exposing your server online
- **Resource monitoring** — Real-time CPU/RAM usage per server
- **Auto-restart** — Automatic crash detection and recovery
- **Auto-scaling** — Dynamic RAM allocation based on usage
- **Backups** — Scheduled world backups with rotation
- **Remote SSH** — Manage servers on remote Linux VPS (Oracle Cloud, etc.)

## Requirements

- macOS 14.0+ (Sonoma)
- Swift 5.9+ (Xcode 15+ or command-line tools)
- [SteamCMD](https://developer.valvesoftware.com/wiki/SteamCMD) (optional, for CS2/ARK servers)
  - `brew install steamcmd`
- Java 17+ (optional, for Minecraft servers)
  - `brew install openjdk@17`

## Build

```bash
git clone https://github.com/Rasmus-03/server-manager.git
cd server-manager
chmod +x build.sh
./build.sh
```

The app will be installed to `/Applications/Server Manager.app`.

## Project Structure

```
src/
  App.swift              # SwiftUI app entry point
  ServerManager.swift    # Core logic: server management, SteamCMD, backups
  ContentView.swift      # UI: dashboard, console, options, mods, files
Resources/
  playit                 # Playit tunnel agent binary
build.sh                 # Build script
```

## License

MIT
