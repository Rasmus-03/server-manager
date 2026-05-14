# Server Manager

Cross-platform game server management tool.

- **macOS**: Native SwiftUI app
- **Linux**: Native GTK3 desktop app (Python)

Manage Minecraft, Counter-Strike 2, ARK: Survival Evolved, and custom game servers.

## Features

- **Multi-server** — Manage multiple servers from one interface
- **One-click setup** — Download Vanilla or Paper servers directly
- **SteamCMD integration** — Install Counter-Strike 2 and ARK dedicated servers
- **Playit tunnel** — Expose your server online via playit.gg
- **Resource monitoring** — Real-time CPU/RAM usage per server
- **Auto-restart** — Automatic crash detection and recovery
- **Auto-scaling** — Dynamic RAM allocation based on usage
- **Backups** — Scheduled world backups with rotation

## Downloads

| Platform | Format | How to get |
|----------|--------|------------|
| **macOS** | `.app` bundle | `./build.sh` (requires Xcode 15+) |
| **Linux** | Python source | `cd src/linux && python3 server-manager.py` |

## Requirements

### macOS
- macOS 14.0+ (Sonoma)
- Swift 5.9+ (Xcode 15+ or command-line tools)
- [playit.gg](https://playit.gg) (optional): `brew install playit`
- Java 17+ (for Minecraft): `brew install openjdk@17`

### Linux
- Python 3.10+
- GTK3: `sudo apt install python3-gi python3-gi-cairo gir1.2-gtk-3.0`
- For clipboard support: `sudo apt install xclip` (X11) or `wl-clipboard` (Wayland)
- Java 17+ (for Minecraft): `sudo apt install openjdk-17-jre-headless`
- [playit.gg](https://playit.gg) (optional): `curl -L https://playit.gg/downloads/playit-linux-amd64 -o /usr/local/bin/playit && chmod +x /usr/local/bin/playit`

## Build & Run

### macOS
```bash
./build.sh
```
Installs to `/Applications/Server Manager.app`.

### Linux
```bash
# Install GTK3 dependencies (Ubuntu/Debian)
sudo apt install python3-gi python3-gi-cairo gir1.2-gtk-3.0 python3-pip

# Run directly
cd src/linux
python3 server-manager.py

# Or install system-wide
cd src/linux
sudo make install
server-manager
```

## Project Structure

```
src/
  App.swift              # SwiftUI entry point (macOS only)
  ServerManager.swift    # Server management logic (macOS only)
  ContentView.swift      # UI views (macOS only)
  linux/
    server-manager.py    # Linux entry point
    requirements.txt     # Python dependencies
    Makefile             # Install/uninstall
    org.server-manager.desktop  # .desktop file for app menu
    core/
      server_manager.py  # Server management core logic (cross-platform)
    ui/
      window.py          # GTK3 UI (sidebar, dashboard, console, config)
Resources/               # macOS app resources
build.sh                 # Build script (works on macOS and Linux)
```

## License

MIT
