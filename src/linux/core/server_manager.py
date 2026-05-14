"""Server management core logic - ported from ServerManager.swift"""

import json
import os
import shutil
import signal
import subprocess
import threading
import time
import uuid
from datetime import datetime

DATA_DIR = os.path.expanduser("~/.server-manager")
SERVERS_FILE = os.path.join(DATA_DIR, "servers.json")

os.makedirs(DATA_DIR, exist_ok=True)

GAME_SERVER_KINDS = {
    "minecraft": {
        "name": "Minecraft",
        "icon": "cube",
        "folder": "minecraft-server",
        "port": "25565",
        "steam_app": None,
    },
    "counter-strike-2": {
        "name": "Counter-Strike 2",
        "icon": "crosshair",
        "folder": "cs2-server",
        "port": "27015",
        "steam_app": 730,
    },
    "ark-survival-evolved": {
        "name": "ARK: Survival Evolved",
        "icon": "mountain",
        "folder": "ark-server",
        "port": "7777",
        "steam_app": 376030,
    },
    "custom": {
        "name": "Custom Game",
        "icon": "application",
        "folder": "game-server",
        "port": "27015",
        "steam_app": None,
    },
}


class ServerInstance:
    def __init__(self, data=None):
        if data is None:
            data = {}
        self.id = data.get("id", uuid.uuid4().hex[:12])
        self.name = data.get("name", "New Server")
        self.server_path = os.path.expanduser(data.get("server_path", ""))
        self.game_kind = data.get("game_kind", "minecraft")
        self.port = data.get("port", GAME_SERVER_KINDS.get(self.game_kind, {}).get("port", "25565"))
        self.ram_gb = data.get("ram_gb", 4)
        self.cpu_threads = data.get("cpu_threads", self._detect_cpu_threads())
        self.auto_restart = data.get("auto_restart", False)
        self.backup_enabled = data.get("backup_enabled", False)
        self.backup_interval_hours = data.get("backup_interval_hours", 6)
        self.max_backups = data.get("max_backups", 10)
        self.public_join_address = data.get("public_join_address", "")
        self.playit_target_address = data.get("playit_target_address", "")
        self.motd = data.get("motd", "A Minecraft Server")
        self.max_players = data.get("max_players", "20")
        self.selected_launch_profile = data.get("selected_launch_profile", "")
        self.custom_executable_path = data.get("custom_executable_path", "")
        self.custom_launch_arguments = data.get("custom_launch_arguments", "")
        self.last_start_time = data.get("last_start_time", None)
        self.crash_count = data.get("crash_count", 0)

        self.process = None
        self.is_running = False
        self.log_output = ""
        self.cpu_usage = 0.0
        self.ram_usage_mb = 0.0
        self.properties = {}
        self.launch_profiles = []
        self.monitor_thread = None
        self._stop_monitor = False

    def _detect_cpu_threads(self):
        try:
            return int(subprocess.check_output(["nproc"], text=True).strip())
        except Exception:
            return os.cpu_count() or 1

    def to_dict(self):
        return {
            "id": self.id,
            "name": self.name,
            "server_path": self.server_path,
            "game_kind": self.game_kind,
            "port": self.port,
            "ram_gb": self.ram_gb,
            "cpu_threads": self.cpu_threads,
            "auto_restart": self.auto_restart,
            "backup_enabled": self.backup_enabled,
            "backup_interval_hours": self.backup_interval_hours,
            "max_backups": self.max_backups,
            "public_join_address": self.public_join_address,
            "playit_target_address": self.playit_target_address,
            "motd": self.motd,
            "max_players": self.max_players,
            "selected_launch_profile": self.selected_launch_profile,
            "custom_executable_path": self.custom_executable_path,
            "custom_launch_arguments": self.custom_launch_arguments,
            "last_start_time": self.last_start_time,
            "crash_count": self.crash_count,
        }

    @property
    def is_minecraft(self):
        return self.game_kind == "minecraft"

    @property
    def properties_file(self):
        return os.path.join(self.server_path, "server.properties")

    @property
    def jvm_args_file(self):
        return os.path.join(self.server_path, "user_jvm_args.txt")

    @property
    def backups_dir(self):
        return os.path.join(self.server_path, "Backups")

    def refresh_launch_profiles(self):
        profiles = []
        if not self.is_minecraft:
            self.launch_profiles = profiles
            return

        forge_root = os.path.join(self.server_path, "libraries", "net", "minecraftforge", "forge")
        if os.path.isdir(forge_root):
            try:
                for ver in os.listdir(forge_root):
                    args_file = os.path.join(forge_root, ver, "unix_args.txt")
                    if os.path.isfile(args_file):
                        parts = ver.split("-", 1)
                        mc_ver = parts[0]
                        forge_ver = parts[1] if len(parts) > 1 else "Forge"
                        rel_args = os.path.join("libraries", "net", "minecraftforge", "forge", ver, "unix_args.txt")
                        profiles.append({
                            "id": f"forge:{ver}",
                            "name": f"Forge {mc_ver}",
                            "mc_version": mc_ver,
                            "loader": f"Forge {forge_ver}",
                            "args": ["@user_jvm_args.txt", f"@{rel_args}", "nogui"],
                        })
            except Exception:
                pass

        for root, dirs, files in os.walk(self.server_path):
            for f in files:
                if f.endswith(".jar") and self._is_server_jar(f):
                    rel = os.path.relpath(os.path.join(root, f), self.server_path)
                    if not rel.startswith("libraries/"):
                        ver = self._jar_version(f)
                        profiles.append({
                            "id": f"jar:{rel}",
                            "name": f"Vanilla {ver}",
                            "mc_version": ver,
                            "loader": "Server Jar",
                            "args": ["@user_jvm_args.txt", "-jar", rel, "nogui"],
                        })

        self.launch_profiles = sorted(profiles, key=lambda p: p["loader"])

    def _is_server_jar(self, name):
        lower = name.lower()
        return any(kw in lower for kw in ["server.jar", "server-", "paper-", "spigot-", "purpur-", "fabric-server"])

    def _jar_version(self, filename):
        import re
        m = re.search(r'\d+\.\d+(\.\d+)?', filename)
        return m.group(0) if m else "Custom"

    def load_properties(self):
        if not os.path.isfile(self.properties_file):
            self.properties = {}
            return
        props = {}
        try:
            with open(self.properties_file) as f:
                for line in f:
                    line = line.strip()
                    if line and not line.startswith("#") and "=" in line:
                        k, _, v = line.partition("=")
                        props[k.strip()] = v.strip()
        except Exception:
            pass
        self.properties = props

    def save_properties(self):
        lines = ["# Minecraft server properties", f"# {datetime.now().isoformat()}", ""]
        for k, v in sorted(self.properties.items()):
            lines.append(f"{k}={v}")
        try:
            os.makedirs(os.path.dirname(self.properties_file), exist_ok=True)
            with open(self.properties_file, "w") as f:
                f.write("\n".join(lines) + "\n")
        except Exception as e:
            print(f"Could not save properties: {e}")

    def get_property(self, key, default=""):
        return self.properties.get(key, default)

    def set_property(self, key, value):
        self.properties[key] = value

    @property
    def server_port(self):
        if self.is_minecraft:
            return self.get_property("server-port", self.port)
        return self.port

    @property
    def local_address(self):
        return f"127.0.0.1:{self.server_port}"

    def find_java(self, required_major):
        candidates = []
        if required_major >= 21:
            for v in range(25, 20, -1):
                candidates.append(f"/usr/lib/jvm/java-{v}-openjdk-amd64/bin/java")
                candidates.append(f"/usr/lib/jvm/java-{v}-openjdk/bin/java")
        candidates.extend([
            "/usr/lib/jvm/java-17-openjdk-amd64/bin/java",
            "/usr/lib/jvm/java-17-openjdk/bin/java",
            "/usr/lib/jvm/java-11-openjdk-amd64/bin/java",
            "/usr/lib/jvm/java-8-openjdk-amd64/bin/java",
            "/usr/bin/java",
        ])
        for c in candidates:
            if os.path.isfile(c) and os.access(c, os.X_OK):
                return c
        try:
            return subprocess.check_output(["which", "java"], text=True).strip()
        except Exception:
            return None

    def java_major_version(self, java_path):
        try:
            out = subprocess.check_output([java_path, "-version"], stderr=subprocess.STDOUT, text=True, timeout=5)
            import re
            m = re.search(r'version "(\d+)', out) or re.search(r'version "1\.(\d+)', out)
            return int(m.group(1)) if m else None
        except Exception:
            return None

    def required_java_major(self, mc_version):
        parts = mc_version.split(".")
        if len(parts) < 2:
            return 17
        major, minor = int(parts[0]), int(parts[1])
        patch = int(parts[2]) if len(parts) > 2 else 0
        if major > 1 or (major == 1 and (minor > 20 or (minor == 20 and patch >= 5))):
            return 21
        if major == 1 and minor >= 18:
            return 17
        if major == 1 and minor == 17:
            return 16
        return 8

    def free_port(self):
        try:
            subprocess.run(["fuser", "-k", f"{self.server_port}/tcp"],
                           capture_output=True, timeout=3)
        except Exception:
            pass

    def save_jvm_args(self):
        threads = max(1, min(self.cpu_threads, os.cpu_count() or 1))
        content = f"""-Xms1G
-Xmx{self.ram_gb}G
-XX:ActiveProcessorCount={threads}
-XX:+UseG1GC
-XX:ParallelGCThreads={threads}
-XX:ConcGCThreads={max(1, threads // 2)}
"""
        try:
            os.makedirs(self.server_path, exist_ok=True)
            with open(self.jvm_args_file, "w") as f:
                f.write(content)
        except Exception as e:
            print(f"Could not save JVM args: {e}")

    def start(self):
        if self.is_running:
            return

        if not os.path.isdir(self.server_path):
            os.makedirs(self.server_path, exist_ok=True)

        self.refresh_launch_profiles()

        if self.is_minecraft:
            profile = None
            for p in self.launch_profiles:
                if p["id"] == self.selected_launch_profile:
                    profile = p
                    break
            if not profile and self.launch_profiles:
                profile = self.launch_profiles[0]
                self.selected_launch_profile = profile["id"]

            if not profile:
                self.log_output = "[Error] No server version found.\n"
                return

            mc_ver = profile.get("mc_version", "1.21")
            java_req = self.required_java_major(mc_ver)
            java_path = self.find_java(java_req)

            if not java_path:
                self.log_output = f"[Error] Java {java_req}+ required but not found.\n"
                return

            self.save_jvm_args()
            self.free_port()
            self.log_output = "[Info] Starting server...\n"

            args = profile["args"]
            self._launch_process(java_path, args)
        else:
            exec_path = self.custom_executable_path
            if not exec_path or not os.access(exec_path, os.X_OK):
                self.log_output = f"[Error] Server executable not found or not executable: {exec_path}\n"
                return
            self.free_port()
            self.log_output = f"[Info] Starting {self.game_kind}...\n"
            args = self._parse_arguments(self.custom_launch_arguments)
            self._launch_process(exec_path, args)

    def _launch_process(self, executable, args):
        try:
            env = os.environ.copy()
            env["HOME"] = os.path.expanduser("~")
            self.process = subprocess.Popen(
                [executable] + args,
                cwd=self.server_path,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                stdin=subprocess.PIPE,
                text=True,
                env=env,
                preexec_fn=os.setsid,
            )
            self.is_running = True
            self.last_start_time = time.time()
            self._stop_monitor = False
            self.monitor_thread = threading.Thread(target=self._monitor_process, daemon=True)
            self.monitor_thread.start()
        except Exception as e:
            self.log_output += f"[Error] {e}\n"
            self.is_running = False
            self.process = None

    def _monitor_process(self):
        try:
            for line in iter(self.process.stdout.readline, ""):
                self.log_output += line
                if len(self.log_output) > 100000:
                    self.log_output = self.log_output[-100000:]
            self.process.wait()
        except Exception:
            pass
        finally:
            self.is_running = False
            self.process = None
            self.cpu_usage = 0
            self.ram_usage_mb = 0
            if self.auto_restart and self.crash_count < 3:
                self._handle_crash()

    def _handle_crash(self):
        self.crash_count += 1
        if self.crash_count >= 3:
            self.log_output += "[Crash] Too many crashes. Auto-restart disabled.\n"
            self.auto_restart = False
            return
        self.log_output += f"[Crash] Restarting in 5s (crash #{self.crash_count})...\n"
        threading.Timer(5.0, self.start).start()

    def stop(self):
        if not self.is_running or not self.process:
            return
        self.send_command("stop")
        try:
            self.process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            os.killpg(os.getpgid(self.process.pid), signal.SIGTERM)
            try:
                self.process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                os.killpg(os.getpgid(self.process.pid), signal.SIGKILL)

    def kill(self):
        if self.process:
            try:
                os.killpg(os.getpgid(self.process.pid), signal.SIGKILL)
            except Exception:
                pass
            self.process = None
            self.is_running = False
            self.cpu_usage = 0
            self.ram_usage_mb = 0

    def send_command(self, command):
        if self.process and self.is_running:
            try:
                self.process.stdin.write(command + "\n")
                self.process.stdin.flush()
            except Exception:
                pass

    def _parse_arguments(self, input_str):
        args = []
        current = ""
        in_quote = None
        escape = False
        for ch in input_str:
            if escape:
                current += ch
                escape = False
                continue
            if ch == "\\":
                escape = True
                continue
            if ch in ("\"", "'"):
                if in_quote == ch:
                    in_quote = None
                elif in_quote is None:
                    in_quote = ch
                else:
                    current += ch
                continue
            if ch.isspace() and in_quote is None:
                if current:
                    args.append(current)
                    current = ""
            else:
                current += ch
        if current:
            args.append(current)
        return args

    def get_resource_usage(self):
        if not self.process or not self.is_running:
            self.cpu_usage = 0
            self.ram_usage_mb = 0
            return
        try:
            out = subprocess.check_output(
                ["ps", "-o", "%cpu=", "-o", "rss=", "-p", str(self.process.pid)],
                text=True, timeout=3
            )
            parts = out.strip().split()
            if len(parts) >= 2:
                self.cpu_usage = float(parts[0])
                self.ram_usage_mb = float(parts[1]) / 1024
        except Exception:
            pass

    def copy_to_clipboard(self, text):
        try:
            subprocess.run(["xclip", "-selection", "clipboard"], input=text.encode(), timeout=3)
        except Exception:
            try:
                subprocess.run(["wl-copy"], input=text.encode(), timeout=3)
            except Exception:
                pass

    def open_folder(self):
        try:
            subprocess.Popen(["xdg-open", self.server_path])
        except Exception:
            pass


class ServerManager:
    def __init__(self):
        self.instances = []
        self.selected_id = None
        self._load()
        self._monitor_resources()

    def _load(self):
        try:
            with open(SERVERS_FILE) as f:
                data = json.load(f)
            self.instances = [ServerInstance(d) for d in data]
            for s in self.instances:
                s.refresh_launch_profiles()
                s.load_properties()
        except (FileNotFoundError, json.JSONDecodeError):
            self.instances = []

    def save(self):
        data = [s.to_dict() for s in self.instances]
        with open(SERVERS_FILE, "w") as f:
            json.dump(data, f, indent=2)

    @property
    def selected(self):
        for s in self.instances:
            if s.id == self.selected_id:
                return s
        return self.instances[0] if self.instances else None

    def add_server(self, name, server_path, game_kind="minecraft"):
        instance = ServerInstance({
            "name": name,
            "server_path": server_path,
            "game_kind": game_kind,
            "port": GAME_SERVER_KINDS.get(game_kind, {}).get("port", "25565"),
            "cpu_threads": os.cpu_count() or 1,
        })
        self.instances.append(instance)
        self.selected_id = instance.id
        self.save()
        return instance

    def remove_server(self, instance_id):
        self.instances = [s for s in self.instances if s.id != instance_id]
        if self.selected_id == instance_id:
            self.selected_id = self.instances[0].id if self.instances else None
        self.save()

    def _monitor_resources(self):
        def loop():
            while True:
                for s in self.instances:
                    if s.is_running:
                        s.get_resource_usage()
                time.sleep(2)

        threading.Thread(target=loop, daemon=True).start()

    def download_vanilla_versions(self):
        import urllib.request
        import json
        try:
            resp = urllib.request.urlopen(
                "https://launchermeta.mojang.com/mc/game/version_manifest_v2.json",
                timeout=10
            )
            data = json.loads(resp.read())
            return [v for v in data.get("versions", []) if v.get("type") == "release"][:50]
        except Exception:
            return []

    def download_paper_versions(self):
        import urllib.request
        import json
        try:
            resp = urllib.request.urlopen(
                "https://api.papermc.io/v2/projects/paper", timeout=10
            )
            data = json.loads(resp.read())
            versions = data.get("versions", [])[-10:]
            result = []
            for ver in versions:
                bresp = urllib.request.urlopen(
                    f"https://api.papermc.io/v2/projects/paper/versions/{ver}/builds",
                    timeout=10
                )
                bdata = json.loads(bresp.read())
                builds = bdata.get("builds", [])
                if builds:
                    latest = builds[-1]
                    result.append({
                        "version": ver,
                        "build": latest["build"],
                        "name": f"Paper {ver} (build {latest['build']})",
                    })
            return result
        except Exception:
            return []

    def download_server_jar(self, instance, version_type, version_id, build=None, accept_eula=False):
        import urllib.request
        import json
        jar_path = os.path.join(instance.server_path, "server.jar")
        os.makedirs(instance.server_path, exist_ok=True)

        if version_type == "vanilla":
            resp = urllib.request.urlopen(
                "https://launchermeta.mojang.com/mc/game/version_manifest_v2.json",
                timeout=10
            )
            manifest = json.loads(resp.read())
            ver_info = next((v for v in manifest["versions"] if v["id"] == version_id), None)
            if not ver_info:
                raise Exception(f"Version {version_id} not found")
            pkg_resp = urllib.request.urlopen(ver_info["url"], timeout=10)
            pkg = json.loads(pkg_resp.read())
            if "server" not in pkg.get("downloads", {}):
                raise Exception("No server download for this version")
            urllib.request.urlretrieve(pkg["downloads"]["server"]["url"], jar_path)

        elif version_type == "paper":
            dl_url = f"https://api.papermc.io/v2/projects/paper/versions/{version_id}/builds/{build}/downloads/paper-{version_id}-{build}.jar"
            urllib.request.urlretrieve(dl_url, jar_path)

        instance.refresh_launch_profiles()
        if instance.launch_profiles:
            instance.selected_launch_profile = instance.launch_profiles[0]["id"]

        if accept_eula:
            with open(os.path.join(instance.server_path, "eula.txt"), "w") as f:
                f.write("eula=true\n")

        instance.save_jvm_args()
        self.save()
