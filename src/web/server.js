const express = require('express');
const path = require('path');
const fs = require('fs');
const { spawn, execSync } = require('child_process');

const app = express();
const PORT = process.env.PORT || 3478;
const DATA_DIR = path.join(process.env.HOME || '/tmp', '.server-manager');
const SERVERS_FILE = path.join(DATA_DIR, 'servers.json');
const LOGS_DIR = path.join(DATA_DIR, 'logs');

if (!fs.existsSync(DATA_DIR)) fs.mkdirSync(DATA_DIR, { recursive: true });
if (!fs.existsSync(LOGS_DIR)) fs.mkdirSync(LOGS_DIR, { recursive: true });

app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

let servers = [];
try { servers = JSON.parse(fs.readFileSync(SERVERS_FILE, 'utf-8')); } catch { servers = []; }
function saveServers() { fs.writeFileSync(SERVERS_FILE, JSON.stringify(servers, null, 2)); }

function runningProcesses() {
  const procs = {};
  try {
    const out = execSync('ps aux', { encoding: 'utf-8', timeout: 5000 });
    for (const line of out.split('\n').slice(1)) {
      const parts = line.trim().split(/\s+/);
      if (parts.length < 11) continue;
      const pid = parseInt(parts[1]);
      const cpu = parseFloat(parts[2]) || 0;
      const mem = parseFloat(parts[3]) || 0;
      const cmd = parts.slice(10).join(' ');
      const rssKB = parseInt(parts[5]) || 0;
      procs[pid] = { pid, cpu, mem, rssKB, cmd: cmd.substring(0, 200) };
    }
  } catch {}
  return procs;
}

function findJava(requiredMajor) {
  const candidates = [];
  if (requiredMajor >= 21) {
    for (let v = 25; v >= 21; v--) {
      candidates.push(`/usr/lib/jvm/java-${v}-openjdk-amd64/bin/java`);
      candidates.push(`/usr/lib/jvm/java-${v}-openjdk/bin/java`);
    }
  }
  candidates.push('/usr/lib/jvm/java-17-openjdk-amd64/bin/java');
  candidates.push('/usr/lib/jvm/java-17-openjdk/bin/java');
  candidates.push('/usr/lib/jvm/java-11-openjdk-amd64/bin/java');
  candidates.push('/usr/lib/jvm/java-8-openjdk-amd64/bin/java');
  candidates.push('/usr/bin/java');
  for (const c of candidates) {
    if (fs.existsSync(c)) return c;
  }
  const which = execSync('which java 2>/dev/null || true', { encoding: 'utf-8' }).trim();
  return which || null;
}

function javaMajorVersion(javaPath) {
  try {
    const out = execSync(`"${javaPath}" -version 2>&1`, { encoding: 'utf-8', timeout: 5000 });
    const m = out.match(/version "(\d+)/);
    if (m) return parseInt(m[1]);
    const m2 = out.match(/version "1\.(\d+)/);
    if (m2) return parseInt(m2[1]);
  } catch {}
  return null;
}

function requiredJava(mcVersion) {
  const parts = mcVersion.split('.').map(Number);
  if (parts.length < 2) return 17;
  if (parts[0] > 1 || (parts[0] === 1 && parts[1] > 20)) return 21;
  if (parts[0] === 1 && parts[1] >= 18) return 17;
  if (parts[0] === 1 && parts[1] === 17) return 16;
  return 8;
}

function freePort(port) {
  try {
    execSync(`fuser -k ${port}/tcp 2>/dev/null; true`, { timeout: 3000 });
  } catch {}
}

function getCpuCount() { try { return parseInt(execSync('nproc', { encoding: 'utf-8' }).trim()) || 1; } catch { return 1; } }

// --- API Routes ---

app.get('/api/servers', (req, res) => {
  const procs = runningProcesses();
  const result = servers.map(s => {
    const proc = procs[s.pid];
    const running = proc && s.pid && s.pid > 0;
    return { ...s, running, cpu: running ? proc.cpu : 0, ramMB: running ? Math.round(proc.rssKB / 1024) : 0 };
  });
  res.json(result);
});

app.post('/api/servers', (req, res) => {
  const { name, path: spath, gameKind, version, eula } = req.body;
  if (!name || !spath) return res.status(400).json({ error: 'Name and path required' });
  const id = Date.now().toString(36) + Math.random().toString(36).slice(2, 6);
  const server = {
    id, name, serverPath: path.resolve(spath.replace(/^~/, process.env.HOME)),
    gameKind: gameKind || 'minecraft', version: version || '',
    selectedLaunchProfile: '',
    launchProfiles: [],
    port: gameKind === 'minecraft' ? '25565' : '27015',
    ramGB: 4, cpuThreads: getCpuCount(),
    autoRestart: false, autoScale: false, backupEnabled: false,
    backupIntervalHours: 6, maxBackups: 10, publicJoinAddress: '',
    playitTargetAddress: '', pid: null, startTime: null,
    crashCount: 0, motd: 'A Minecraft Server', maxPlayers: 20,
    properties: {}, ops: [], whitelist: [], logs: '',
  };
  servers.push(server);
  saveServers();
  res.json(server);
});

app.delete('/api/servers/:id', (req, res) => {
  const idx = servers.findIndex(s => s.id === req.params.id);
  if (idx === -1) return res.status(404).json({ error: 'Not found' });
  stopServer(servers[idx]);
  servers.splice(idx, 1);
  saveServers();
  res.json({ ok: true });
});

app.get('/api/servers/:id/logs', (req, res) => {
  const server = servers.find(s => s.id === req.params.id);
  if (!server) return res.status(404).json({ error: 'Not found' });
  res.json({ logs: server.logs || '' });
});

app.post('/api/servers/:id/start', (req, res) => {
  const server = servers.find(s => s.id === req.params.id);
  if (!server) return res.status(404).json({ error: 'Not found' });
  try { startServer(server); res.json({ ok: true }); }
  catch (e) { res.status(500).json({ error: e.message }); }
});

app.post('/api/servers/:id/stop', (req, res) => {
  const server = servers.find(s => s.id === req.params.id);
  if (!server) return res.status(404).json({ error: 'Not found' });
  stopServer(server);
  res.json({ ok: true });
});

app.post('/api/servers/:id/kill', (req, res) => {
  const server = servers.find(s => s.id === req.params.id);
  if (!server) return res.status(404).json({ error: 'Not found' });
  if (server.pid) {
    try { execSync(`kill -9 ${server.pid} 2>/dev/null; true`); } catch {}
    server.pid = null;
    server.startTime = null;
    saveServers();
  }
  res.json({ ok: true });
});

app.get('/api/servers/:id/stats', (req, res) => {
  const server = servers.find(s => s.id === req.params.id);
  if (!server) return res.status(404).json({ error: 'Not found' });
  const procs = runningProcesses();
  const proc = procs[server.pid];
  const running = !!(proc && server.pid);
  const cpu = running ? proc.cpu : 0;
  const ramMB = running ? Math.round(proc.rssKB / 1024) : 0;
  res.json({ running, cpu, ramMB, ramGB: server.ramGB, cpuThreads: server.cpuThreads });
});

app.put('/api/servers/:id', (req, res) => {
  const server = servers.find(s => s.id === req.params.id);
  if (!server) return res.status(404).json({ error: 'Not found' });
  Object.assign(server, req.body);
  saveServers();
  res.json(server);
});

app.post('/api/servers/:id/command', (req, res) => {
  const server = servers.find(s => s.id === req.params.id);
  if (!server) return res.status(404).json({ error: 'Not found' });
  const { command } = req.body;
  if (!command) return res.status(400).json({ error: 'Command required' });
  sendCommand(server, command);
  res.json({ ok: true });
});

app.get('/api/versions/vanilla', async (req, res) => {
  try {
    const resp = await fetch('https://launchermeta.mojang.com/mc/game/version_manifest_v2.json');
    const data = await resp.json();
    res.json(data.versions.filter(v => v.type === 'release').slice(0, 50));
  } catch (e) { res.status(500).json({ error: e.message }); }
});

app.get('/api/versions/paper', async (req, res) => {
  try {
    const resp = await fetch('https://api.papermc.io/v2/projects/paper');
    const data = await resp.json();
    const versions = data.versions.slice(-50).reverse();
    const result = [];
    for (const ver of versions.slice(0, 10)) {
      const bResp = await fetch(`https://api.papermc.io/v2/projects/paper/versions/${ver}/builds`);
      const bData = await bResp.json();
      const latest = bData.builds?.slice(-1)[0];
      if (latest) result.push({ version: ver, build: latest.build, displayName: `Paper ${ver} (build ${latest.build})` });
    }
    res.json(result);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

app.post('/api/servers/:id/install', async (req, res) => {
  const server = servers.find(s => s.id === req.params.id);
  if (!server) return res.status(404).json({ error: 'Not found' });
  const { type, version, build } = req.body;
  try {
    if (type === 'vanilla') {
      const manifestResp = await fetch('https://launchermeta.mojang.com/mc/game/version_manifest_v2.json');
      const manifest = await manifestResp.json();
      const verInfo = manifest.versions.find(v => v.id === version);
      if (!verInfo) return res.status(400).json({ error: 'Version not found' });
      const pkgResp = await fetch(verInfo.url);
      const pkg = await pkgResp.json();
      if (!pkg.downloads?.server) return res.status(400).json({ error: 'No server download' });
      const jarResp = await fetch(pkg.downloads.server.url);
      const jarPath = path.join(server.serverPath, 'server.jar');
      const stream = fs.createWriteStream(jarPath);
      stream.write(Buffer.from(await jarResp.arrayBuffer()));
      stream.end();
      await new Promise(r => stream.on('finish', r));
      server.launchProfiles = [{ id: `jar:server.jar`, name: `Vanilla ${version}`, mcVersion: version, args: ['-jar', 'server.jar', 'nogui'] }];
      server.selectedLaunchProfile = server.launchProfiles[0].id;
      if (req.body.eula) fs.writeFileSync(path.join(server.serverPath, 'eula.txt'), 'eula=true\n');
      saveServers();
    } else if (type === 'paper') {
      const dlResp = await fetch(`https://api.papermc.io/v2/projects/paper/versions/${version}/builds/${build}/downloads/paper-${version}-${build}.jar`);
      const jarPath = path.join(server.serverPath, 'server.jar');
      const stream = fs.createWriteStream(jarPath);
      stream.write(Buffer.from(await dlResp.arrayBuffer()));
      stream.end();
      await new Promise(r => stream.on('finish', r));
      server.launchProfiles = [{ id: `jar:server.jar`, name: `Paper ${version}`, mcVersion: version, args: ['-jar', 'server.jar', 'nogui'] }];
      server.selectedLaunchProfile = server.launchProfiles[0].id;
      if (req.body.eula) fs.writeFileSync(path.join(server.serverPath, 'eula.txt'), 'eula=true\n');
      saveServers();
    }
    res.json({ ok: true });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// --- Server Management ---

function startServer(server) {
  if (server.pid) {
    const procs = runningProcesses();
    if (procs[server.pid]) return;
  }

  const mcVersion = server.launchProfiles?.find(p => p.id === server.selectedLaunchProfile)?.mcVersion || '1.21';
  const javaReq = requiredJava(mcVersion);
  const javaPath = findJava(javaReq);
  if (!javaPath) throw new Error(`Java ${javaReq}+ required but not found`);

  if (!server.serverPath || !fs.existsSync(server.serverPath)) {
    fs.mkdirSync(server.serverPath, { recursive: true });
  }

  freePort(server.port);

  saveJvmArgs(server);

  const profile = server.launchProfiles?.find(p => p.id === server.selectedLaunchProfile);
  const args = ['@user_jvm_args.txt', ...(profile?.args || ['-jar', 'server.jar', 'nogui'])];
  const proc = spawn(javaPath, args, { cwd: server.serverPath, stdio: ['pipe', 'pipe', 'pipe'] });
  server.pid = proc.pid;
  server.startTime = Date.now();
  server.logs = '';

  const logFile = path.join(LOGS_DIR, `${server.id}.log`);
  const logStream = fs.createWriteStream(logFile, { flags: 'a' });

  proc.stdout.on('data', d => {
    const text = d.toString();
    server.logs = (server.logs + text).slice(-100000);
    logStream.write(text);
    if (text.includes('Done') && text.includes('For help')) server.running = true;
  });
  proc.stderr.on('data', d => {
    const text = d.toString();
    server.logs = (server.logs + text).slice(-100000);
    logStream.write(text);
  });
  proc.on('exit', (code) => {
    server.pid = null;
    server.startTime = null;
    saveServers();
    logStream.end();
    if (server.autoRestart && server.crashCount < 3) handleCrash(server);
  });

  saveServers();
}

function stopServer(server) {
  if (!server.pid) return;
  try {
    sendCommand(server, 'stop');
    setTimeout(() => {
      if (server.pid) {
        try { execSync(`kill ${server.pid} 2>/dev/null; true`); } catch {}
        server.pid = null;
        server.startTime = null;
        saveServers();
      }
    }, 10000);
  } catch { try { execSync(`kill ${server.pid} 2>/dev/null; true`); } catch {} }
}

function sendCommand(server, cmd) {
  if (!server.pid) return;
  const procDir = `/proc/${server.pid}/fd/0`;
  if (fs.existsSync(procDir)) {
    try { execSync(`echo "${cmd.replace(/"/g, '\\"')}" > ${procDir} 2>/dev/null`); } catch {}
  }
}

function handleCrash(server) {
  server.crashCount = (server.crashCount || 0) + 1;
  if (server.crashCount >= 3) { server.autoRestart = false; saveServers(); return; }
  setTimeout(() => { try { startServer(server); } catch {} }, 5000);
}

function saveJvmArgs(server) {
  const threads = Math.min(Math.max(server.cpuThreads || 1, 1), getCpuCount());
  const content = `-Xms1G\n-Xmx${server.ramGB || 4}G\n-XX:ActiveProcessorCount=${threads}\n-XX:+UseG1GC\n`;
  fs.writeFileSync(path.join(server.serverPath, 'user_jvm_args.txt'), content);
}

// --- Monitor cleanup ---
setInterval(() => {
  const procs = runningProcesses();
  for (const s of servers) {
    if (s.pid && !procs[s.pid]) { s.pid = null; s.startTime = null; }
  }
  saveServers();
}, 10000);

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Server Manager Web UI running at http://0.0.0.0:${PORT}`);
  console.log(`Data directory: ${DATA_DIR}`);
});
