import SwiftUI
import AppKit

enum PanelSection: String, CaseIterable, Identifiable {
    case dashboard
    case console
    case options
    case players
    case files
    case network
    case backups
    case updates
    case mods
    case remote

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: return "Server"
        case .console: return "Console"
        case .options: return "Options"
        case .players: return "Players"
        case .files: return "Files"
        case .network: return "Network"
        case .backups: return "Backups"
        case .updates: return "Updates"
        case .mods: return "Mods"
        case .remote: return "Remote"
        }
    }

    var icon: String {
        switch self {
        case .dashboard: return "server.rack"
        case .console: return "terminal"
        case .options: return "slider.horizontal.3"
        case .players: return "person.2"
        case .files: return "folder"
        case .network: return "network"
        case .backups: return "externaldrive"
        case .updates: return "arrow.up.circle"
        case .mods: return "puzzlepiece.extension"
        case .remote: return "antenna.radiowaves.left.and.right"
        }
    }
}

struct ContentView: View {
    @StateObject private var manager = ServerManager()
    @StateObject private var remoteManager = RemoteServerManager()
    @AppStorage("isDarkMode") private var isDarkMode = false
    @State private var selectedSection: PanelSection = .dashboard

    var body: some View {
        NavigationSplitView {
            SidebarView(manager: manager, selectedSection: $selectedSection)
        } detail: {
            ZStack {
                Color.panelBackground.ignoresSafeArea()
                if selectedSection == .remote {
                    RemoteServersView(remoteManager: remoteManager)
                        .padding(24)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                } else if let instance = manager.selectedInstance {
                    selectedView(instance: instance)
                        .padding(24)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                } else {
                    AllServersDashboard(manager: manager)
                        .padding(24)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
            .frame(minWidth: 800, idealWidth: 1024, maxWidth: .infinity, minHeight: 720, maxHeight: .infinity)
        }
        .navigationSplitViewStyle(.prominentDetail)
        .frame(minWidth: 1080, maxWidth: .infinity, minHeight: 720, maxHeight: .infinity)
    }

    @ViewBuilder
    private func selectedView(instance: ServerInstance) -> some View {
        switch selectedSection {
        case .dashboard: DashboardView(manager: manager, instance: instance)
        case .console: ConsoleView(instance: instance)
        case .options: OptionsView(instance: instance)
        case .players: PlayersView(instance: instance)
        case .files: FilesView(instance: instance)
        case .network: NetworkView(instance: instance)
        case .backups: BackupsView(instance: instance)
        case .updates: UpdatesView(instance: instance)
        case .mods: ModsView(instance: instance)
        case .remote: EmptyView()
        }
    }
}

struct AllServersDashboard: View {
    @ObservedObject var manager: ServerManager
    @State private var showingAddServer = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Server Manager")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Text("\(manager.instances.count) server\(manager.instances.count == 1 ? "" : "s") configured")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        showingAddServer = true
                    } label: {
                        Label("Add Server", systemImage: "plus")
                            .frame(width: 140, height: 36)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.panelBlue)
                }

                if manager.instances.isEmpty {
                    PanelCard("Welcome", icon: "server.rack") {
                        VStack(spacing: 12) {
                            Image(systemName: "server.rack")
                                .font(.system(size: 40))
                                .foregroundColor(.panelBlue)
                            Text("No servers yet. Create your first server to get started.")
                                .foregroundStyle(.secondary)
                            Button {
                                showingAddServer = true
                            } label: {
                                Label("Create Server", systemImage: "plus")
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 30)
                    }
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 14)], spacing: 14) {
                        ForEach(manager.instances) { instance in
                            ServerOverviewCard(manager: manager, instance: instance)
                        }
                    }

                    PanelCard("Resource Overview", icon: "chart.line.uptrend.xyaxis") {
                        VStack(spacing: 10) {
                            let totalRamAllocated = manager.instances.reduce(0) { $0 + $1.ramGB }
                            let totalRamUsed = manager.instances.reduce(0.0) { $0 + $1.ramUsageMB / 1024 }
                            let totalCpu = manager.instances.reduce(0.0) { $0 + $1.cpuUsagePercent }
                            let onlineCount = manager.instances.filter(\.isRunning).count

                            HStack(spacing: 20) {
                                MetricTile(title: "Online", value: "\(onlineCount)/\(manager.instances.count)", icon: "power", tint: onlineCount > 0 ? .green : .red)
                                MetricTile(title: "Total RAM", value: "\(Int(totalRamAllocated)) GB", icon: "memorychip", tint: .orange)
                                MetricTile(title: "RAM Used", value: String(format: "%.1f GB", totalRamUsed), icon: "chart.bar.fill", tint: .orange)
                                MetricTile(title: "Total CPU", value: String(format: "%.0f%%", totalCpu), icon: "cpu", tint: .green)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .sheet(isPresented: $showingAddServer) {
            ServerCreationSheet(manager: manager)
        }
    }
}

struct ServerOverviewCard: View {
    @ObservedObject var manager: ServerManager
    @ObservedObject var instance: ServerInstance

    var body: some View {
        PanelCard(instance.config.name, icon: "server.rack") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Circle()
                        .fill(instance.isRunning ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text(instance.isRunning ? "Online" : "Offline")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(instance.config.gameKind.displayName)
                        .font(.caption)
                        .foregroundColor(.panelBlue)
                }

                InfoLine(title: "Software", value: instance.softwareName)
                InfoLine(title: "Path", value: instance.serverPath)
                if instance.isRunning {
                    InfoLine(title: "CPU", value: "\(Int(instance.cpuUsagePercent.rounded()))%")
                    InfoLine(title: "RAM", value: "\(Int(instance.ramUsageMB.rounded())) MB / \(instance.ramGB) GB")
                }

                HStack(spacing: 8) {
                    Button {
                        manager.selectedInstanceID = instance.id
                    } label: {
                        Label("Select", systemImage: "arrow.forward")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.panelBlue)
                    .controlSize(.small)

                    Button {
                        instance.isRunning ? instance.stop() : instance.start()
                    } label: {
                        Label(instance.isRunning ? "Stop" : "Start", systemImage: instance.isRunning ? "stop.fill" : "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(instance.isRunning ? .red : .green)
                    .controlSize(.small)
                }
            }
        }
    }
}

struct SidebarView: View {
    @ObservedObject var manager: ServerManager
    @Binding var selectedSection: PanelSection
    @State private var showingAddServer = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Server Manager")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                HStack {
                    Picker("Selected Server", selection: $manager.selectedInstanceID) {
                        ForEach(manager.instances) { instance in
                            Text(instance.config.name).tag(Optional(instance.id))
                        }
                    }
                    .labelsHidden()
                    
                    if let selectedID = manager.selectedInstanceID {
                        Button {
                            manager.removeServer(id: selectedID)
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                        .help("Remove Server")
                    }
                }
                
                if let instance = manager.selectedInstance {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(instance.isRunning ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        Text(instance.isRunning ? "Online" : "Offline")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack {
                    Toggle(isOn: Binding(
                        get: { UserDefaults.standard.bool(forKey: "isDarkMode") },
                        set: { newValue in
                            UserDefaults.standard.set(newValue, forKey: "isDarkMode")
                            NSApp.appearance = NSAppearance(named: newValue ? .darkAqua : .aqua)
                        }
                    )) {
                        Image(systemName: NSApp.effectiveAppearance.name == .darkAqua ? "moon.fill" : "sun.max")
                    }
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    Text("Dark Mode").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.top, 4)
                .onAppear {
                    if UserDefaults.standard.bool(forKey: "isDarkMode") {
                        NSApp.appearance = NSAppearance(named: .darkAqua)
                    }
                }
            }

            VStack(spacing: 4) {
                ForEach(PanelSection.allCases) { section in
                    Button {
                        selectedSection = section
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: section.icon)
                                .frame(width: 18)
                            Text(section.title)
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(selectedSection == section ? Color.white : Color.primary)
                    .background(selectedSection == section ? Color.panelBlue : Color.clear)
                    .cornerRadius(8)
                }
            }

            Spacer()
            
            Button {
                showingAddServer = true
            } label: {
                    Label("Add Server", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .padding(.bottom, 8)

            PanelCard("Quick Actions", icon: "bolt") {
                VStack(spacing: 8) {
                    Button {
                        manager.selectedInstance?.openServerFolder()
                    } label: {
                        Label("Open Folder", systemImage: "folder")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(manager.selectedInstance == nil)

                    Button {
                        manager.selectedInstance?.createBackup()
                    } label: {
                        Label("Backup Now", systemImage: "externaldrive")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(manager.selectedInstance == nil || !(manager.selectedInstance?.isMinecraftServer ?? false))

                    Button {
                        manager.selectedInstance?.loadAllSettings()
                    } label: {
                        Label("Reload Files", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(manager.selectedInstance == nil)

                    Divider()

                    Button(role: .destructive) {
                        manager.selectedInstance?.forceKillAllProcesses()
                    } label: {
                        Label("Force Kill Server", systemImage: "xmark.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .disabled(manager.selectedInstance == nil)
                }
            }

        }
        .padding(16)
        .background(Color.sidebarBackground)
        .navigationSplitViewColumnWidth(min: 230, ideal: 250, max: 280)
        .sheet(isPresented: $showingAddServer) {
            ServerCreationSheet(manager: manager)
        }
    }
}

struct DashboardView: View {
    @ObservedObject var manager: ServerManager
    @ObservedObject var instance: ServerInstance

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HeaderBar(manager: manager, instance: instance)
                ServerStartMenu(manager: manager)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 12)], spacing: 12) {
                    MetricTile(title: "Game", value: instance.config.gameKind.displayName, icon: instance.config.gameKind.icon, tint: .panelBlue)
                    MetricTile(title: "Status", value: instance.isRunning ? "Online" : "Offline", icon: "power", tint: instance.isRunning ? .green : .red)
                    MetricTile(title: "Software", value: instance.softwareName, icon: "shippingbox", tint: .panelBlue)
                    MetricTile(title: "CPU Use", value: instance.isRunning ? "\(Int(instance.cpuUsagePercent.rounded()))%" : "0%", icon: "cpu", tint: .green)
                    MetricTile(title: "RAM Use", value: instance.isRunning ? "\(Int(instance.ramUsageMB.rounded())) MB" : "0 MB", icon: "memorychip", tint: .orange)
                    MetricTile(title: "RAM", value: "\(instance.ramGB) GB", icon: "memorychip", tint: .orange)
                    MetricTile(title: "CPU Threads", value: "\(instance.cpuThreads)", icon: "speedometer", tint: .teal)
                    MetricTile(title: "Slots", value: instance.maxPlayers, icon: "person.2", tint: .purple)
                    MetricTile(title: "Port", value: instance.serverPort, icon: "point.3.connected.trianglepath.dotted", tint: .teal)
                }

                PanelCard("Resource Usage", icon: "chart.line.uptrend.xyaxis") {
                    VStack(spacing: 12) {
                        ResourceMeter(
                            title: "CPU",
                            value: instance.cpuUsagePercent,
                            maxValue: Double(max(instance.cpuThreads, 1) * 100),
                            valueText: instance.isRunning ? "\(Int(instance.cpuUsagePercent.rounded()))%" : "0%",
                            detail: "\(instance.cpuThreads) thread allocation",
                            tint: .green
                        )
                        ResourceMeter(
                            title: "RAM",
                            value: instance.ramUsageMB,
                            maxValue: Double(max(instance.ramGB, 1) * 1024),
                            valueText: instance.isRunning ? "\(Int(instance.ramUsageMB.rounded())) MB" : "0 MB",
                            detail: "\(instance.ramGB) GB allocation",
                            tint: .orange
                        )
                    }
                }

                PanelCard("Connection", icon: "link") {
                    VStack(spacing: 10) {
                        AddressRow(title: "Minecraft address", value: instance.publicJoinAddress) {
                            instance.copyToClipboard(instance.publicJoinAddress)
                        }
                        AddressRow(title: "Playit endpoint", value: instance.playitTargetAddress) {
                            instance.copyToClipboard(instance.playitTargetAddress)
                        }
                        AddressRow(title: "Local server", value: instance.localAddress) {
                            instance.copyToClipboard(instance.localAddress)
                        }
                    }
                }

                HStack(alignment: .top, spacing: 12) {
                    if instance.isMinecraftServer {
                        PanelCard("Server Commands", icon: "command") {
                            QuickCommandGrid(instance: instance)
                        }
                    } else {
                        PanelCard("Process Log", icon: "terminal") {
                            LogBox(text: instance.logOutput.isEmpty ? "Process output will appear here." : instance.logOutput, height: 170, color: .white)
                        }
                    }

                    PanelCard("Network Log", icon: "waveform") {
                        LogBox(text: instance.networkLog.isEmpty ? "No network output yet." : instance.networkLog, height: 170, color: .green)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }
}

struct HeaderBar: View {
    @ObservedObject var manager: ServerManager
    @ObservedObject var instance: ServerInstance
    @State private var showingCreateServer = false

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            VStack(alignment: .leading, spacing: 7) {
                Text(instance.isMinecraftServer ? instance.motd : instance.config.name)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .lineLimit(2)
                HStack(spacing: 10) {
                    StatusPill(text: instance.isRunning ? "Online" : "Offline", color: instance.isRunning ? .green : .red)
                    StatusPill(text: instance.config.gameKind.displayName, color: .panelBlue)
                    StatusPill(text: instance.softwareName, color: .panelBlue)
                    Text(instance.publicJoinAddress)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 10) {
                if instance.isMinecraftServer {
                    Picker("Version", selection: $instance.config.selectedLaunchProfileID) {
                        if instance.launchProfiles.isEmpty {
                            Text("No version").tag("")
                        } else {
                            ForEach(instance.launchProfiles) { profile in
                                Text(profile.displayName).tag(profile.id)
                            }
                        }
                    }
                    .frame(width: 220)
                    .disabled(instance.isRunning || instance.launchProfiles.isEmpty)
                } else {
                    Label(instance.config.gameKind.displayName, systemImage: instance.config.gameKind.icon)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(width: 220, alignment: .trailing)
                }

                HStack(spacing: 8) {
                    Button {
                        showingCreateServer = true
                    } label: {
                        Label("Add Server", systemImage: "plus.circle")
                            .font(.headline)
                            .frame(width: 142, height: 40)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)

                    Button {
                        instance.isRunning ? instance.stop() : instance.start()
                    } label: {
                        Label(instance.isRunning ? "Stop" : "Start", systemImage: instance.isRunning ? "stop.fill" : "play.fill")
                            .font(.headline)
                            .frame(width: 124, height: 40)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(instance.isRunning ? .red : .green)
                    .controlSize(.large)
                    .disabled(!instance.isRunning && !instance.canAttemptStart)
                }
            }
        }
        .padding(20)
        .background(Color.cardBackground)
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.cardStroke))
        .sheet(isPresented: $showingCreateServer) {
            ServerCreationSheet(manager: manager)
        }
    }
}

struct ServerStartMenu: View {
    @ObservedObject var manager: ServerManager
    @State private var isExpanded = false

    var body: some View {
        PanelCard("Start Menu", icon: "power") {
            DisclosureGroup(isExpanded: $isExpanded) {
                VStack(spacing: 8) {
                    if manager.instances.isEmpty {
                        Text("No servers created yet.")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 10)
                    } else {
                        ForEach(manager.instances) { instance in
                            ManagedServerRow(
                                manager: manager,
                                instance: instance,
                                isSelected: manager.selectedInstanceID == instance.id
                            )
                        }
                    }
                }
                .padding(.top, 8)
            } label: {
                HStack {
                    Label("Alle servere", systemImage: "server.rack")
                        .font(.headline)
                    Spacer()
                    Text("\(manager.instances.count)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.panelBlue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.panelBlue.opacity(0.12))
                        .cornerRadius(8)
                }
            }
        }
        .onAppear {
            if manager.instances.count > 1 {
                isExpanded = true
            }
        }
    }
}

struct ManagedServerRow: View {
    @ObservedObject var manager: ServerManager
    @ObservedObject var instance: ServerInstance
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(instance.isRunning ? Color.green : Color.red)
                .frame(width: 9, height: 9)

            VStack(alignment: .leading, spacing: 3) {
                Text(instance.config.name)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                Text("\(instance.config.gameKind.displayName) - \(instance.serverPath)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(minWidth: 180, maxWidth: .infinity, alignment: .leading)

            if instance.isMinecraftServer {
                Picker("Version", selection: $instance.config.selectedLaunchProfileID) {
                    if instance.launchProfiles.isEmpty {
                        Text("No version").tag("")
                    } else {
                        ForEach(instance.launchProfiles) { profile in
                            Text(profile.displayName).tag(profile.id)
                        }
                    }
                }
                .labelsHidden()
                .frame(width: 190)
                .disabled(instance.isRunning || instance.launchProfiles.isEmpty)
            } else {
                Text(instance.config.gameKind.displayName)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(width: 190, alignment: .leading)
            }

            Button {
                manager.selectedInstanceID = instance.id
            } label: {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .foregroundStyle(isSelected ? Color.panelBlue : Color.secondary)
            .help("Select Server")

            Button {
                instance.isRunning ? instance.stop() : instance.start()
            } label: {
                Label(instance.isRunning ? "Stop" : "Start", systemImage: instance.isRunning ? "stop.fill" : "play.fill")
                    .frame(width: 92)
            }
            .buttonStyle(.borderedProminent)
            .tint(instance.isRunning ? .red : .green)
            .disabled(!instance.isRunning && !instance.canAttemptStart)
        }
        .padding(10)
        .background(isSelected ? Color.panelBlue.opacity(0.10) : Color.rowBackground)
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(isSelected ? Color.panelBlue.opacity(0.25) : Color.clear))
    }
}

private enum ServerCreationMode: String, CaseIterable, Identifiable {
    case downloadVanilla = "Download Vanilla"
    case downloadForge = "Download Forge"
    case downloadPaper = "Download Paper"
    case existingFolder = "Existing Folder"

    var id: String { rawValue }
}

struct ServerCreationSheet: View {
    @ObservedObject var manager: ServerManager
    @Environment(\.dismiss) private var dismiss

    @State private var serverName = ""
    @State private var serverPath = ""
    @State private var selectedGameKind: GameServerKind = .minecraft
    @State private var mode: ServerCreationMode = .downloadVanilla
    @State private var vanillaVersions: [MinecraftVersionSummary] = []
    @State private var selectedVanillaVersionID = ""
    @State private var forgeMinecraftVersion = "1.21.1"
    @State private var forgeVersions: [ForgeVersionSummary] = []
    @State private var selectedForgeVersionID = ""
    @State private var paperVersions: [ServerManager.PaperVersionSummary] = []
    @State private var selectedPaperVersionID = ""
    @State private var isLoadingPaperVersions = false
    @State private var customExecutablePath = ""
    @State private var customLaunchArguments = ""
    @State private var customServerPort = GameServerKind.counterStrike2.defaultPort
    @State private var installWithSteamCMD = true
    @State private var validateSteamCMDInstall = true
    @State private var installedProfiles: [ServerLaunchProfile] = []
    @State private var selectedInstalledProfileID = ""
    @State private var acceptsEULA = false
    @State private var isLoadingVersions = false
    @State private var isLoadingForgeVersions = false
    @State private var isCreating = false
    @State private var message = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Create Server")
                .font(.headline)

            Picker("Game", selection: $selectedGameKind) {
                ForEach(GameServerKind.allCases) { gameKind in
                    Label(gameKind.displayName, systemImage: gameKind.icon).tag(gameKind)
                }
            }

            LabeledTextField(title: "Server Name", text: $serverName)

            VStack(alignment: .leading, spacing: 5) {
                Text("Server Folder")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    TextField("Server Folder", text: $serverPath)
                        .textFieldStyle(.roundedBorder)
                    Button {
                        chooseFolder()
                    } label: {
                        Label("Choose", systemImage: "folder")
                    }
                    .buttonStyle(.bordered)
                }
            }

            if selectedGameKind == .minecraft {
                Picker("Setup", selection: $mode) {
                    ForEach(ServerCreationMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                switch mode {
                case .downloadVanilla:
                    VStack(alignment: .leading, spacing: 8) {
                        Picker("Minecraft Version", selection: $selectedVanillaVersionID) {
                            if vanillaVersions.isEmpty {
                                Text(isLoadingVersions ? "Loading versions..." : message.isEmpty ? "No versions loaded" : "Failed to load").tag("")
                            } else {
                                ForEach(vanillaVersions) { version in
                                    Text(version.id).tag(version.id)
                                }
                            }
                        }
                        .disabled(vanillaVersions.isEmpty || isLoadingVersions || isCreating)

                        HStack {
                            Button {
                                loadVanillaVersions(force: true)
                            } label: {
                                Label(isLoadingVersions ? "Loading..." : "Reload Versions", systemImage: "arrow.clockwise")
                            }
                            .buttonStyle(.bordered)
                            .disabled(isLoadingVersions || isCreating)

                            if isLoadingVersions {
                                ProgressView()
                                    .controlSize(.small)
                            }

                            if !message.isEmpty && vanillaVersions.isEmpty && !isLoadingVersions {
                                Button {
                                    loadVanillaVersions(force: true)
                                } label: {
                                    Label("Retry", systemImage: "exclamationmark.arrow.trianglehead.counterclockwise")
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.orange)
                                .controlSize(.small)
                            }
                        }
                    }
                case .downloadForge:
                    VStack(alignment: .leading, spacing: 8) {
                        LabeledTextField(title: "Minecraft Version", text: $forgeMinecraftVersion)

                        Picker("Forge Build", selection: $selectedForgeVersionID) {
                            if matchingForgeVersions.isEmpty {
                                Text(isLoadingForgeVersions ? "Loading Forge builds..." : message.isEmpty ? "No Forge builds found" : "Failed to load").tag("")
                            } else {
                                ForEach(matchingForgeVersions) { version in
                                    Text(version.displayName).tag(version.id)
                                }
                            }
                        }
                        .disabled(matchingForgeVersions.isEmpty || isLoadingForgeVersions || isCreating)

                        HStack {
                            Button {
                                loadForgeVersions(force: true)
                            } label: {
                                Label(isLoadingForgeVersions ? "Loading..." : "Reload Forge Builds", systemImage: "arrow.clockwise")
                            }
                            .buttonStyle(.bordered)
                            .disabled(isLoadingForgeVersions || isCreating)

                            if isLoadingForgeVersions {
                                ProgressView()
                                    .controlSize(.small)
                            }

                            if !message.isEmpty && matchingForgeVersions.isEmpty && !isLoadingForgeVersions {
                                Button {
                                    loadForgeVersions(force: true)
                                } label: {
                                    Label("Retry", systemImage: "exclamationmark.arrow.trianglehead.counterclockwise")
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.orange)
                                .controlSize(.small)
                            }
                        }
                    }
                case .downloadPaper:
                    VStack(alignment: .leading, spacing: 8) {
                        Picker("Paper Version", selection: $selectedPaperVersionID) {
                            if paperVersions.isEmpty {
                                Text(isLoadingPaperVersions ? "Loading Paper versions..." : message.isEmpty ? "No Paper builds found" : "Failed to load").tag("")
                            } else {
                                ForEach(paperVersions) { version in
                                    Text(version.displayName).tag(version.id)
                                }
                            }
                        }
                        .disabled(paperVersions.isEmpty || isLoadingPaperVersions || isCreating)

                        HStack {
                            Button {
                                loadPaperVersions(force: true)
                            } label: {
                                Label(isLoadingPaperVersions ? "Loading..." : "Reload Paper Builds", systemImage: "arrow.clockwise")
                            }
                            .buttonStyle(.bordered)
                            .disabled(isLoadingPaperVersions || isCreating)

                            if isLoadingPaperVersions {
                                ProgressView()
                                    .controlSize(.small)
                            }

                            if !message.isEmpty && paperVersions.isEmpty && !isLoadingPaperVersions {
                                Button {
                                    loadPaperVersions(force: true)
                                } label: {
                                    Label("Retry", systemImage: "exclamationmark.arrow.trianglehead.counterclockwise")
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.orange)
                                .controlSize(.small)
                            }
                        }
                    }
                case .existingFolder:
                    VStack(alignment: .leading, spacing: 8) {
                        Picker("Installed Version", selection: $selectedInstalledProfileID) {
                            if installedProfiles.isEmpty {
                                Text("No installed versions found").tag("")
                            } else {
                                ForEach(installedProfiles) { profile in
                                    Text(profile.displayName).tag(profile.id)
                                }
                            }
                        }
                        .disabled(installedProfiles.isEmpty || isCreating)

                        Button {
                            refreshInstalledProfiles()
                        } label: {
                            Label("Scan Folder", systemImage: "magnifyingglass")
                        }
                        .buttonStyle(.bordered)
                        .disabled(serverPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCreating)
                    }
                }

                Toggle("Accept Minecraft EULA", isOn: $acceptsEULA)
                    .disabled(isCreating)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    if let preset = selectedGameKind.steamCMDPreset {
                        Toggle("Install with SteamCMD", isOn: $installWithSteamCMD)
                            .disabled(isCreating)

                        InfoLine(title: "Steam App", value: "\(preset.appID)")
                        InfoLine(title: "Platform", value: preset.platform ?? "default")

                        Text(preset.note)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Toggle("Validate files", isOn: $validateSteamCMDInstall)
                            .disabled(isCreating || !installWithSteamCMD)
                    }

                    if !installWithSteamCMD || selectedGameKind.steamCMDPreset == nil {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Server Executable")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 8) {
                                TextField("Server Executable", text: $customExecutablePath)
                                    .textFieldStyle(.roundedBorder)
                                Button {
                                    chooseExecutable()
                                } label: {
                                    Label("Choose", systemImage: "terminal")
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }

                    LabeledTextField(title: "Launch Arguments", text: $customLaunchArguments)
                    LabeledTextField(title: "Port", text: $customServerPort)
                }
            }

            if !message.isEmpty {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.red)
            }

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .disabled(isCreating)

                Spacer()

                Button {
                    createServer()
                } label: {
                    if isCreating {
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 86)
                    } else {
                        Label("Create", systemImage: "plus")
                            .frame(width: 86)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canCreate)
            }
        }
        .padding(20)
        .frame(width: 480)
        .onAppear {
            if serverName.isEmpty {
                serverName = "Server \(manager.instances.count + 1)"
            }
            if serverPath.isEmpty {
                serverPath = NSHomeDirectory() + "/minecraft-server-\(manager.instances.count + 1)"
            }
            refreshInstalledProfiles()
            loadVanillaVersions(force: false)
            loadForgeVersions(force: false)
            loadPaperVersions(force: false)
        }
        .onChange(of: serverPath) { _, _ in
            refreshInstalledProfiles()
        }
        .onChange(of: forgeMinecraftVersion) { _, _ in
            selectFirstMatchingForgeVersion()
        }
        .onChange(of: selectedGameKind) { _, newGameKind in
            applyDefaults(for: newGameKind)
        }
    }

    private var selectedVanillaVersion: MinecraftVersionSummary? {
        vanillaVersions.first { $0.id == selectedVanillaVersionID }
    }

    private var matchingForgeVersions: [ForgeVersionSummary] {
        let requestedVersion = forgeMinecraftVersion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !requestedVersion.isEmpty else { return forgeVersions }
        return forgeVersions.filter { $0.minecraftVersion == requestedVersion }
    }

    private var selectedForgeVersion: ForgeVersionSummary? {
        matchingForgeVersions.first { $0.id == selectedForgeVersionID }
    }

    private var selectedPaperVersion: ServerManager.PaperVersionSummary? {
        paperVersions.first { $0.id == selectedPaperVersionID }
    }

    private var canCreate: Bool {
        let hasName = !serverName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasPath = !serverPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasVersion: Bool
        switch mode {
        case .downloadVanilla:
            hasVersion = selectedGameKind == .minecraft && selectedVanillaVersion != nil && !isLoadingVersions
        case .downloadForge:
            hasVersion = selectedGameKind == .minecraft && selectedForgeVersion != nil && !isLoadingForgeVersions
        case .downloadPaper:
            hasVersion = selectedGameKind == .minecraft && selectedPaperVersion != nil && !isLoadingPaperVersions
        case .existingFolder:
            hasVersion = selectedGameKind == .minecraft
        }
        if selectedGameKind == .minecraft {
            return hasName && hasPath && hasVersion && !isCreating
        }
        let canInstallWithSteamCMD = installWithSteamCMD && selectedGameKind.steamCMDPreset != nil
        let hasExecutable = !customExecutablePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return hasName && hasPath && (canInstallWithSteamCMD || hasExecutable) && !isCreating
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            serverPath = url.path
            if serverName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                serverName = url.lastPathComponent
            }
        }
    }

    private func chooseExecutable() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            customExecutablePath = url.path
        }
    }

    private func applyDefaults(for gameKind: GameServerKind) {
        if serverName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || serverName.hasPrefix("Server ") {
            serverName = "\(gameKind.displayName) \(manager.instances.count + 1)"
        }
        if serverPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || serverPath.contains("/minecraft-server-") {
            serverPath = NSHomeDirectory() + "/\(gameKind.defaultFolderName)-\(manager.instances.count + 1)"
        }
        if gameKind != .minecraft {
            installWithSteamCMD = gameKind.steamCMDPreset != nil
            customServerPort = gameKind.steamCMDPreset?.port ?? gameKind.defaultPort
            customLaunchArguments = gameKind.steamCMDPreset?.launchArguments ?? ""
            customExecutablePath = ""
        } else {
            installWithSteamCMD = false
        }
    }

    private func loadVanillaVersions(force: Bool) {
        guard force || vanillaVersions.isEmpty else { return }
        isLoadingVersions = true
        message = ""

        Task {
            do {
                let versions = try await ServerManager.fetchVanillaVersions()
                await MainActor.run {
                    vanillaVersions = versions
                    selectedVanillaVersionID = versions.first?.id ?? ""
                    isLoadingVersions = false
                }
            } catch {
                await MainActor.run {
                    isLoadingVersions = false
                    message = "Could not load vanilla versions: \(error.localizedDescription)"
                }
            }
        }
    }

    private func loadPaperVersions(force: Bool) {
        guard force || paperVersions.isEmpty else { return }
        isLoadingPaperVersions = true
        message = ""

        Task {
            do {
                let versions = try await ServerManager.fetchPaperVersions()
                await MainActor.run {
                    paperVersions = versions
                    selectedPaperVersionID = versions.first?.id ?? ""
                    isLoadingPaperVersions = false
                }
            } catch {
                await MainActor.run {
                    isLoadingPaperVersions = false
                    message = "Could not load Paper builds: \(error.localizedDescription)"
                }
            }
        }
    }

    private func loadForgeVersions(force: Bool) {
        guard force || forgeVersions.isEmpty else { return }
        isLoadingForgeVersions = true
        message = ""

        Task {
            do {
                let versions = try await ServerManager.fetchForgeVersions()
                await MainActor.run {
                    forgeVersions = versions
                    selectFirstMatchingForgeVersion()
                    isLoadingForgeVersions = false
                }
            } catch {
                await MainActor.run {
                    isLoadingForgeVersions = false
                    message = "Could not load Forge builds: \(error.localizedDescription)"
                }
            }
        }
    }

    private func selectFirstMatchingForgeVersion() {
        if !matchingForgeVersions.contains(where: { $0.id == selectedForgeVersionID }) {
            selectedForgeVersionID = matchingForgeVersions.first?.id ?? ""
        }
    }

    private func refreshInstalledProfiles() {
        installedProfiles = ServerInstance.discoverLaunchProfiles(in: serverPath)
        if !installedProfiles.contains(where: { $0.id == selectedInstalledProfileID }) {
            selectedInstalledProfileID = installedProfiles.first?.id ?? ""
        }
    }

    private func createServer() {
        let trimmedName = serverName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPath = serverPath.trimmingCharacters(in: .whitespacesAndNewlines)
        isCreating = true
        message = ""

        Task {
            do {
                if selectedGameKind == .minecraft {
                    switch mode {
                    case .downloadVanilla:
                        guard let version = selectedVanillaVersion else { throw ServerSetupError.invalidVersion }
                        try await manager.createVanillaServer(
                            name: trimmedName,
                            path: trimmedPath,
                            version: version,
                            acceptsEULA: acceptsEULA
                        )
                    case .downloadForge:
                        guard let version = selectedForgeVersion else { throw ServerSetupError.invalidVersion }
                        try await manager.createForgeServer(
                            name: trimmedName,
                            path: trimmedPath,
                            version: version,
                            acceptsEULA: acceptsEULA
                        )
                    case .downloadPaper:
                        guard let version = selectedPaperVersion else { throw ServerSetupError.invalidVersion }
                        try await manager.createPaperServer(
                            name: trimmedName,
                            path: trimmedPath,
                            version: version,
                            acceptsEULA: acceptsEULA
                        )
                    case .existingFolder:
                        try await MainActor.run {
                            try manager.addServer(
                                name: trimmedName,
                                path: trimmedPath,
                                selectedLaunchProfileID: selectedInstalledProfileID,
                                acceptsEULA: acceptsEULA
                            )
                        }
                    }
                } else {
                    if installWithSteamCMD, selectedGameKind.steamCMDPreset != nil {
                        try await manager.createSteamCMDGameServer(
                            name: trimmedName,
                            path: trimmedPath,
                            gameKind: selectedGameKind,
                            launchArguments: customLaunchArguments,
                            serverPort: customServerPort,
                            validate: validateSteamCMDInstall
                        )
                    } else {
                        try await MainActor.run {
                            try manager.createGenericGameServer(
                                name: trimmedName,
                                path: trimmedPath,
                                gameKind: selectedGameKind,
                                executablePath: customExecutablePath,
                                launchArguments: customLaunchArguments,
                                serverPort: customServerPort
                            )
                        }
                    }
                }

                await MainActor.run {
                    isCreating = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isCreating = false
                    message = error.localizedDescription
                }
            }
        }
    }
}

struct ConsoleView: View {
    @ObservedObject var instance: ServerInstance
    @State private var command = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                PageTitle(title: "Console", subtitle: instance.isRunning ? "Server process is accepting commands." : "Start the server to send commands.")
                Spacer()
                Button {
                    instance.logOutput = ""
                } label: {
                    Label("Clear", systemImage: "trash")
                }
                .buttonStyle(.bordered)
            }

            LogBox(text: instance.logOutput.isEmpty ? "Console output will appear here." : instance.logOutput, height: nil, color: .white)

            HStack(spacing: 10) {
                TextField("Command", text: $command)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { sendCommand() }

                Button {
                    sendCommand()
                } label: {
                    Label("Send", systemImage: "paperplane.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func sendCommand() {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        instance.sendCommand(trimmed)
        command = ""
    }
}

struct OptionsView: View {
    @ObservedObject var instance: ServerInstance

    var body: some View {
        ScrollView {
            if instance.isMinecraftServer {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        PageTitle(title: "Options", subtitle: "Changes are written to server.properties.")
                        Spacer()
                        Button {
                            instance.saveSettings()
                        } label: {
                            Label("Save Options", systemImage: "square.and.arrow.down")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.panelBlue)
                    }

                    if !instance.lastSavedMessage.isEmpty {
                        Text(instance.lastSavedMessage)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 340), spacing: 14)], spacing: 14) {
                        PanelCard("Software", icon: "shippingbox") {
                            VStack(alignment: .leading, spacing: 12) {
                                Picker("Minecraft Version", selection: $instance.config.selectedLaunchProfileID) {
                                    if instance.launchProfiles.isEmpty {
                                        Text("No installed versions found").tag("")
                                    } else {
                                        ForEach(instance.launchProfiles) { profile in
                                            Text(profile.displayName).tag(profile.id)
                                        }
                                    }
                                }
                                .disabled(instance.isRunning || instance.launchProfiles.isEmpty)

                                if let profile = instance.selectedLaunchProfile {
                                    InfoLine(title: "Loader", value: profile.loader)
                                    InfoLine(title: "Launch file", value: profile.detail)
                                }

                                Button {
                                    instance.refreshLaunchProfiles()
                                } label: {
                                    Label("Reload Versions", systemImage: "arrow.clockwise")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .disabled(instance.isRunning)
                            }
                        }

                        PanelCard("Identity", icon: "tag") {
                            VStack(alignment: .leading, spacing: 12) {
                                MOTDDesigner(instance: instance)
                                LabeledTextField(title: "Level Name", text: textBinding("level-name", fallback: "world"))
                                LabeledTextField(title: "Seed", text: textBinding("level-seed"))
                            }
                        }

                        PanelCard("Gameplay", icon: "gamecontroller") {
                            VStack(alignment: .leading, spacing: 12) {
                                Picker("Gamemode", selection: textBinding("gamemode", fallback: "survival")) {
                                    ForEach(["survival", "creative", "adventure", "spectator"], id: \.self) { Text($0.capitalized).tag($0) }
                                }
                                Picker("Difficulty", selection: textBinding("difficulty", fallback: "easy")) {
                                    ForEach(["peaceful", "easy", "normal", "hard"], id: \.self) { Text($0.capitalized).tag($0) }
                                }
                                Toggle("Hardcore", isOn: boolBinding("hardcore"))
                                Toggle("PVP", isOn: boolBinding("pvp", fallback: true))
                                Toggle("Force Gamemode", isOn: boolBinding("force-gamemode"))
                            }
                        }

                        PanelCard("Access", icon: "person.badge.key") {
                            VStack(alignment: .leading, spacing: 12) {
                                Stepper("Slots: \(instance.intProperty("max-players", fallback: 20))", value: intBinding("max-players", fallback: 20), in: 1...100)
                                Toggle("Whitelist", isOn: boolBinding("white-list"))
                                Toggle("Online Mode", isOn: boolBinding("online-mode", fallback: true))
                                Toggle("Command Blocks", isOn: boolBinding("enable-command-block"))
                                Toggle("Allow Flight", isOn: boolBinding("allow-flight"))
                            }
                        }

                        PanelCard("World", icon: "globe.europe.africa") {
                            VStack(alignment: .leading, spacing: 12) {
                                Toggle("Nether", isOn: boolBinding("allow-nether", fallback: true))
                                Toggle("Animals", isOn: boolBinding("spawn-animals", fallback: true))
                                Toggle("Monsters", isOn: boolBinding("spawn-monsters", fallback: true))
                                Toggle("NPCs", isOn: boolBinding("spawn-npcs", fallback: true))
                                Stepper("Spawn Protection: \(instance.intProperty("spawn-protection", fallback: 16))", value: intBinding("spawn-protection", fallback: 16), in: 0...256)
                            }
                        }

                        PanelCard("Performance", icon: "gauge.with.dots.needle.67percent") {
                            VStack(alignment: .leading, spacing: 12) {
                                Stepper("RAM Allocation: \(instance.ramGB) GB", value: $instance.ramGB, in: 1...max(ServerInstance.maxSystemRamGB, 1))
                                Stepper("CPU Threads: \(instance.cpuThreads)", value: $instance.cpuThreads, in: 1...ServerInstance.maxCPUThreads)
                                Stepper("View Distance: \(instance.intProperty("view-distance", fallback: 10))", value: intBinding("view-distance", fallback: 10), in: 2...32)
                                Stepper("Simulation Distance: \(instance.intProperty("simulation-distance", fallback: 10))", value: intBinding("simulation-distance", fallback: 10), in: 2...32)
                                Stepper("Max Tick Time: \(instance.intProperty("max-tick-time", fallback: 60000))", value: intBinding("max-tick-time", fallback: 60000), in: 10000...120000, step: 5000)
                            }
                        }

                        PanelCard("Recovery", icon: "arrow.clockwise") {
                            VStack(alignment: .leading, spacing: 12) {
                                Toggle("Auto-restart on crash", isOn: Binding(
                                    get: { instance.autoRestart },
                                    set: { instance.autoRestart = $0 }
                                ))
                                .help("Automatically restarts the server if it crashes unexpectedly (max 3 restarts)")
                                if !instance.isRunning, instance.crashCount > 0 {
                                    HStack {
                                        Text("Crashes since last clean stop: \(instance.crashCount)")
                                            .font(.caption)
                                            .foregroundStyle(.orange)
                                        Button("Reset Count") {
                                            instance.crashCount = 0
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                    }
                                }
                            }
                        }

                        PanelCard("Auto-scaling", icon: "chart.line.uptrend.xyaxis") {
                            VStack(alignment: .leading, spacing: 12) {
                                Toggle("Auto-scale RAM", isOn: Binding(
                                    get: { instance.autoScaleEnabled },
                                    set: { enabled in
                                        instance.autoScaleEnabled = enabled
                                        if enabled { instance.startAutoScaling() }
                                        else { instance.stopAutoScaling() }
                                    }
                                ))
                                .help("Dynamically adjust RAM allocation based on usage (30s intervals)")
                                Text("When enabled, RAM is adjusted up (if >85% used) or down (if <30% used) in 1 GB steps.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        PanelCard("Resource Pack", icon: "paintpalette") {
                            VStack(alignment: .leading, spacing: 12) {
                                LabeledTextField(title: "URL", text: textBinding("resource-pack"))
                                LabeledTextField(title: "SHA1", text: textBinding("resource-pack-sha1"))
                                Toggle("Require Resource Pack", isOn: boolBinding("require-resource-pack"))
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            } else {
                GenericGameOptionsView(instance: instance)
            }
        }
    }

    private func textBinding(_ key: String, fallback: String = "") -> Binding<String> {
        Binding(
            get: { instance.property(key, fallback: fallback) },
            set: { instance.setProperty(key, value: $0) }
        )
    }

    private func boolBinding(_ key: String, fallback: Bool = false) -> Binding<Bool> {
        Binding(
            get: { instance.boolProperty(key, fallback: fallback) },
            set: { instance.setBoolProperty(key, value: $0) }
        )
    }

    private func intBinding(_ key: String, fallback: Int) -> Binding<Int> {
        Binding(
            get: { instance.intProperty(key, fallback: fallback) },
            set: { instance.setIntProperty(key, value: $0) }
        )
    }
}

struct GenericGameOptionsView: View {
    @ObservedObject var instance: ServerInstance

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PageTitle(title: "Options", subtitle: instance.config.gameKind.displayName)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 340), spacing: 14)], spacing: 14) {
                PanelCard("Game", icon: instance.config.gameKind.icon) {
                    VStack(alignment: .leading, spacing: 12) {
                        InfoLine(title: "Type", value: instance.config.gameKind.displayName)
                        LabeledTextField(title: "Port", text: configBinding(\.customServerPort))
                    }
                }

                PanelCard("Launch", icon: "terminal") {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Executable")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 8) {
                                TextField("Executable", text: configBinding(\.customExecutablePath))
                                    .textFieldStyle(.roundedBorder)
                                Button {
                                    chooseExecutable()
                                } label: {
                                    Label("Choose", systemImage: "folder")
                                }
                                .buttonStyle(.bordered)
                            }
                        }

                        LabeledTextField(title: "Arguments", text: configBinding(\.customLaunchArguments))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func configBinding(_ keyPath: WritableKeyPath<ServerConfiguration, String>) -> Binding<String> {
        Binding(
            get: { instance.config[keyPath: keyPath] },
            set: { newValue in
                var newConfig = instance.config
                newConfig[keyPath: keyPath] = newValue
                instance.config = newConfig
            }
        )
    }

    private func chooseExecutable() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            var newConfig = instance.config
            newConfig.customExecutablePath = url.path
            instance.config = newConfig
        }
    }
}

struct PlayersView: View {
    @ObservedObject var instance: ServerInstance
    @State private var playerName = ""

    var body: some View {
        ScrollView {
            if instance.isMinecraftServer {
                VStack(alignment: .leading, spacing: 16) {
                    PageTitle(title: "Players", subtitle: "Manage operators and whitelist through server commands.")

                    PanelCard("Player Command", icon: "person.crop.circle.badge.plus") {
                        HStack(spacing: 10) {
                            TextField("Minecraft username", text: $playerName)
                                .textFieldStyle(.roundedBorder)
                            Button("OP") { runPlayerCommand("op") }
                                .disabled(!canRunCommand)
                            Button("De-OP") { runPlayerCommand("deop") }
                                .disabled(!canRunCommand)
                            Button("Whitelist Add") { runWhitelistCommand("add") }
                                .disabled(!canRunCommand)
                            Button("Whitelist Remove") { runWhitelistCommand("remove") }
                                .disabled(!canRunCommand)
                        }
                    }

                    HStack(alignment: .top, spacing: 12) {
                        PlayerListCard(title: "Operators", icon: "crown", players: instance.ops, emptyText: "No operators in ops.json")
                        PlayerListCard(title: "Whitelist", icon: "checkmark.shield", players: instance.whitelist, emptyText: "Whitelist is empty")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    PageTitle(title: "Players", subtitle: instance.config.gameKind.displayName)
                    PanelCard("Player Management", icon: "person.2") {
                        Text("Player tools are available for Minecraft servers.")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 18)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
    }

    private var canRunCommand: Bool {
        instance.isRunning && !playerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func runPlayerCommand(_ command: String) {
        let name = playerName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        instance.sendCommand("\(command) \(name)")
    }

    private func runWhitelistCommand(_ action: String) {
        let name = playerName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        instance.sendCommand("whitelist \(action) \(name)")
    }
}

struct FilesView: View {
    @ObservedObject var instance: ServerInstance

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PageTitle(title: "Files", subtitle: instance.serverPath)

                if instance.isMinecraftServer {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 340), spacing: 14)], spacing: 14) {
                        FileShortcutCard(title: "Server Properties", detail: "server.properties", icon: "slider.horizontal.3") {
                            instance.openFile(instance.propertiesFile)
                        }
                        FileShortcutCard(title: "Latest Log", detail: "logs/latest.log", icon: "doc.text.magnifyingglass") {
                            instance.openFile("\(instance.serverPath)/logs/latest.log")
                        }
                        FileShortcutCard(title: "World Folder", detail: "world", icon: "globe") {
                            instance.openFile("\(instance.serverPath)/world")
                        }
                        FileShortcutCard(title: "Mods Folder", detail: "mods", icon: "puzzlepiece.extension") {
                            instance.openFile("\(instance.serverPath)/mods")
                        }
                        FileShortcutCard(title: "Whitelist", detail: "whitelist.json", icon: "checkmark.shield") {
                            instance.openFile(instance.whitelistFile)
                        }
                        FileShortcutCard(title: "Operators", detail: "ops.json", icon: "crown") {
                            instance.openFile(instance.opsFile)
                        }
                    }
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 340), spacing: 14)], spacing: 14) {
                        FileShortcutCard(title: "Server Folder", detail: instance.serverPath, icon: "folder") {
                            instance.openServerFolder()
                        }
                        if !instance.config.customExecutablePath.isEmpty {
                            FileShortcutCard(title: "Executable", detail: instance.config.customExecutablePath, icon: "terminal") {
                                instance.openFile(instance.config.customExecutablePath)
                            }
                        }
                    }
                }

                Button {
                    instance.openServerFolder()
                } label: {
                    Label("Open Server Folder", systemImage: "folder")
                }
                .buttonStyle(.borderedProminent)
                .tint(.panelBlue)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }
}

struct NetworkView: View {
    @ObservedObject var instance: ServerInstance
    @State private var editJoinAddress = ""
    @State private var editPlayitEndpoint = ""
    @State private var isEditing = false
    @State private var playitStatus = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PageTitle(title: "Network", subtitle: "Playit tunnel and local server addresses.")

                if !playitInstalled {
                    PanelCard("Playit Not Found", icon: "exclamationmark.triangle") {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Playit tunnel agent is required to expose your server online.")
                                .foregroundStyle(.secondary)
                            Text("Install it via Homebrew:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("brew install playit")
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                                .padding(8)
                                .background(Color.rowBackground)
                                .cornerRadius(6)
                            Text("Then run: playit -s to set up your account")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                PanelCard("Addresses", icon: "network") {
                    VStack(spacing: 10) {
                        HStack {
                            AddressRow(title: "Join address", value: instance.publicJoinAddress) {
                                instance.copyToClipboard(instance.publicJoinAddress)
                            }
                            Button {
                                editJoinAddress = instance.publicJoinAddress
                                editPlayitEndpoint = instance.playitTargetAddress
                                isEditing = true
                            } label: {
                                Image(systemName: "pencil")
                            }
                            .buttonStyle(.bordered)
                            .help("Edit tunnel addresses")
                        }
                        AddressRow(title: "Direct Playit endpoint", value: instance.playitTargetAddress) {
                            instance.copyToClipboard(instance.playitTargetAddress)
                        }
                        AddressRow(title: "Local target", value: instance.localAddress) {
                            instance.copyToClipboard(instance.localAddress)
                        }
                        AddressRow(title: "Current status", value: instance.tunnelURL) {
                            instance.copyToClipboard(instance.tunnelURL)
                        }
                    }
                }

                PanelCard("Playit Log", icon: "waveform") {
                    LogBox(text: instance.networkLog.isEmpty ? "Playit output will appear here." : instance.networkLog, height: nil, color: .green)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .sheet(isPresented: $isEditing) {
            editSheet
        }
    }

    private var playitInstalled: Bool {
        FileManager.default.isExecutableFile(atPath: ServerInstance.playitBin)
    }

    private var editSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Edit Tunnel Addresses")
                .font(.headline)

            VStack(alignment: .leading, spacing: 5) {
                Text("Join Address")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("e.g. my-server.joinmc.link", text: $editJoinAddress)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("Playit Endpoint")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("e.g. my-server.at.ply.gg:12345", text: $editPlayitEndpoint)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Button("Cancel") {
                    isEditing = false
                }
                Spacer()
                Button("Save") {
                    var config = instance.config
                    config.publicJoinAddress = editJoinAddress
                    config.playitTargetAddress = editPlayitEndpoint
                    instance.config = config
                    isEditing = false
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 400)
    }
}

struct QuickCommandGrid: View {
    @ObservedObject var instance: ServerInstance

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 8)], spacing: 8) {
            CommandButton(title: "Save", icon: "externaldrive", enabled: instance.isRunning) { instance.sendCommand("save-all") }
            CommandButton(title: "List", icon: "list.bullet", enabled: instance.isRunning) { instance.sendCommand("list") }
            CommandButton(title: "Day", icon: "sun.max", enabled: instance.isRunning) { instance.sendCommand("time set day") }
            CommandButton(title: "Clear Weather", icon: "cloud.sun", enabled: instance.isRunning) { instance.sendCommand("weather clear") }
        }
    }
}

struct CommandButton: View {
    let title: String
    let icon: String
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .disabled(!enabled)
    }
}

struct MetricTile: View {
    let title: String
    let value: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(tint)
                Spacer()
            }
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
                .lineLimit(1)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBackground)
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.cardStroke))
    }
}

struct ResourceMeter: View {
    let title: String
    let value: Double
    let maxValue: Double
    let valueText: String
    let detail: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Text(valueText)
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.semibold)
            }

            ProgressView(value: min(max(value, 0), safeMaxValue), total: safeMaxValue)
                .progressViewStyle(.linear)
                .tint(tint)

            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(Color.rowBackground)
        .cornerRadius(8)
    }

    private var safeMaxValue: Double {
        max(maxValue, 1)
    }
}

struct PanelCard<Content: View>: View {
    let title: String
    let icon: String?
    private let content: Content

    init(_ title: String, icon: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .foregroundStyle(Color.panelBlue)
                }
                Text(title)
                    .font(.headline)
                Spacer()
            }
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color.cardBackground)
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.cardStroke))
    }
}

struct PageTitle: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.largeTitle)
                .fontWeight(.bold)
            Text(subtitle)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }
}

struct StatusPill: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .foregroundStyle(color)
            .background(color.opacity(0.12))
            .cornerRadius(8)
    }
}

struct AddressRow: View {
    let title: String
    let value: String
    let copy: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
            }
            Spacer()
            Button(action: copy) {
                Label("Copy", systemImage: "doc.on.doc")
            }
            .buttonStyle(.bordered)
        }
        .padding(10)
        .background(Color.rowBackground)
        .cornerRadius(8)
    }
}

struct LogTextView: NSViewRepresentable {
    let text: String
    let color: Color

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder
        scroll.drawsBackground = false

        let tv = NSTextView()
        tv.isEditable = false
        tv.isSelectable = true
        tv.font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize(for: .small), weight: .regular)
        tv.textColor = NSColor(color)
        tv.backgroundColor = .clear
        tv.isVerticallyResizable = true
        tv.autoresizingMask = [.width]

        scroll.documentView = tv
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let tv = scroll.documentView as? NSTextView else { return }
        if tv.string != text {
            let wasAtBottom = tv.visibleRect.maxY >= tv.bounds.maxY - 5
            tv.string = text
            tv.textColor = NSColor(color)
            tv.font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize(for: .small), weight: .regular)
            if wasAtBottom {
                tv.scrollToEndOfDocument(nil)
            }
        }
    }
}

struct LogBox: View {
    let text: String
    let height: CGFloat?
    let color: Color

    var body: some View {
        LogTextView(text: text, color: color)
            .frame(maxWidth: .infinity, maxHeight: height == nil ? .infinity : nil)
            .frame(height: height)
            .background(Color.black)
            .cornerRadius(8)
    }
}

struct LabeledTextField: View {
    let title: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField(title, text: $text)
                .textFieldStyle(.roundedBorder)
        }
    }
}

struct MOTDWordToken: Identifiable, Equatable {
    let id = UUID()
    var text: String
    var colorCode: String
    var bold = false
    var italic = false
    var underlined = false
    var lineBreakAfter = false
}

struct MOTDDesigner: View {
    @ObservedObject var instance: ServerInstance
    @State private var words: [MOTDWordToken] = []
    @State private var newWord = ""

    private let symbols = ["★", "✦", "◆", "♦", "⚔", "⛏", "⚡", "✔", "»", "«", "|", "•"]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            RichMOTDPreview(words: words)

            HStack {
                TextField("Add word or phrase", text: $newWord)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { addNewWords() }
                Button {
                    addNewWords()
                } label: {
                    Label("Add", systemImage: "plus")
                }
                .buttonStyle(.bordered)
                .disabled(newWord.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            ScrollView {
                VStack(spacing: 8) {
                    ForEach($words) { $word in
                        MOTDWordRow(word: $word) {
                            removeWord(word.id)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            .frame(maxHeight: 220)

            VStack(alignment: .leading, spacing: 8) {
                Text("Symbols")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 42), spacing: 6)], spacing: 6) {
                    ForEach(symbols, id: \.self) { symbol in
                        Button(symbol) {
                            words.append(MOTDWordToken(text: symbol, colorCode: "6", bold: true))
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }

            HStack {
                PresetButton(title: "SMP") {
                    applyPreset([
                        MOTDWordToken(text: "★", colorCode: "6", bold: true),
                        MOTDWordToken(text: "Rasmus", colorCode: "b", bold: true),
                        MOTDWordToken(text: "SMP", colorCode: "f", bold: true, lineBreakAfter: true),
                        MOTDWordToken(text: "Survival", colorCode: "a"),
                        MOTDWordToken(text: "Quests", colorCode: "e"),
                        MOTDWordToken(text: "Community", colorCode: "d")
                    ])
                }
                PresetButton(title: "Forge") {
                    applyPreset([
                        MOTDWordToken(text: "⚒", colorCode: "6", bold: true),
                        MOTDWordToken(text: "Modded", colorCode: "b", bold: true),
                        MOTDWordToken(text: "Forge", colorCode: "f", bold: true, lineBreakAfter: true),
                        MOTDWordToken(text: "Explore", colorCode: "a"),
                        MOTDWordToken(text: "Build", colorCode: "e"),
                        MOTDWordToken(text: "Survive", colorCode: "c")
                    ])
                }
                PresetButton(title: "PvP") {
                    applyPreset([
                        MOTDWordToken(text: "⚔", colorCode: "c", bold: true),
                        MOTDWordToken(text: "Arena", colorCode: "4", bold: true),
                        MOTDWordToken(text: "PvP", colorCode: "f", bold: true, lineBreakAfter: true),
                        MOTDWordToken(text: "Duels", colorCode: "e"),
                        MOTDWordToken(text: "Events", colorCode: "b"),
                        MOTDWordToken(text: "Rewards", colorCode: "a")
                    ])
                }
                Spacer()
                Button {
                    words = MOTDWordToken.parse(instance.formattedMOTD)
                } label: {
                    Label("Reset", systemImage: "arrow.uturn.backward")
                }
                .buttonStyle(.bordered)
            }
        }
        .onAppear {
            if words.isEmpty {
                words = MOTDWordToken.parse(instance.formattedMOTD)
            }
        }
        .onChange(of: words) { _, newWords in
            instance.setFormattedMOTD(MOTDWordToken.formattedString(from: newWords))
        }
    }

    private func addNewWords() {
        let pieces = newWord
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)

        guard !pieces.isEmpty else { return }
        let colorCycle = ["b", "a", "e", "d", "f"]
        for piece in pieces {
            let colorCode = colorCycle[words.count % colorCycle.count]
            words.append(MOTDWordToken(text: piece, colorCode: colorCode))
        }
        newWord = ""
    }

    private func removeWord(_ id: UUID) {
        words.removeAll { $0.id == id }
    }

    private func applyPreset(_ presetWords: [MOTDWordToken]) {
        words = presetWords
    }
}

struct MOTDWordRow: View {
    @Binding var word: MOTDWordToken
    let remove: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            TextField("Word", text: $word.text)
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 90)

            Picker("Color", selection: $word.colorCode) {
                ForEach(MinecraftMOTDColor.palette) { motdColor in
                    Text(motdColor.name).tag(motdColor.code)
                }
            }
            .labelsHidden()
            .frame(width: 128)

            FormatButton(title: "B", isActive: word.bold) { word.bold.toggle() }
            FormatButton(title: "I", isActive: word.italic) { word.italic.toggle() }
            FormatButton(title: "U", isActive: word.underlined) { word.underlined.toggle() }
            FormatButton(title: "Line", isActive: word.lineBreakAfter) { word.lineBreakAfter.toggle() }

            Button(role: .destructive, action: remove) {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.borderless)
        }
        .padding(8)
        .background(Color.rowBackground)
        .cornerRadius(8)
    }
}

struct FormatButton: View {
    let title: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .buttonStyle(.bordered)
            .tint(isActive ? .panelBlue : .secondary)
    }
}

struct PresetButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .buttonStyle(.bordered)
    }
}

struct RichMOTDPreview: View {
    let words: [MOTDWordToken]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Preview")
                .font(.caption)
                .foregroundStyle(.secondary)
            richText
                .font(.system(.body, design: .monospaced))
                .lineLimit(2)
                .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
                .padding(10)
                .background(Color.black)
                .cornerRadius(8)
        }
    }

    private var richText: Text {
        var output = Text("")
        let visibleWords = words.filter { !$0.text.isEmpty }

        for (index, word) in visibleWords.enumerated() {
            let suffix = word.lineBreakAfter ? "\n" : (index == visibleWords.count - 1 ? "" : " ")
            var piece = Text(word.text + suffix)
                .foregroundColor(MinecraftMOTDColor.color(for: word.colorCode).color)

            if word.bold { piece = piece.bold() }
            if word.italic { piece = piece.italic() }
            if word.underlined { piece = piece.underline() }

            output = output + piece
        }

        return visibleWords.isEmpty ? Text("Minecraft Server").foregroundColor(.white) : output
    }
}

extension MOTDWordToken {
    static func parse(_ formattedMOTD: String) -> [MOTDWordToken] {
        var words: [MOTDWordToken] = []
        var currentText = ""
        var colorCode = "f"
        var bold = false
        var italic = false
        var underlined = false
        var iterator = formattedMOTD.makeIterator()

        func appendCurrent(lineBreakAfter: Bool = false) {
            let trimmedText = currentText.trimmingCharacters(in: .whitespaces)
            guard !trimmedText.isEmpty else {
                if lineBreakAfter, !words.isEmpty {
                    words[words.count - 1].lineBreakAfter = true
                }
                currentText = ""
                return
            }

            words.append(MOTDWordToken(
                text: trimmedText,
                colorCode: colorCode,
                bold: bold,
                italic: italic,
                underlined: underlined,
                lineBreakAfter: lineBreakAfter
            ))
            currentText = ""
        }

        while let character = iterator.next() {
            if character == "\u{00A7}", let codeCharacter = iterator.next() {
                let code = String(codeCharacter).lowercased()
                if MinecraftMOTDColor.palette.contains(where: { $0.code == code }) {
                    colorCode = code
                    bold = false
                    italic = false
                    underlined = false
                } else if code == "l" {
                    bold = true
                } else if code == "o" {
                    italic = true
                } else if code == "n" {
                    underlined = true
                } else if code == "r" {
                    colorCode = "f"
                    bold = false
                    italic = false
                    underlined = false
                }
                continue
            }

            if character == "\n" {
                appendCurrent(lineBreakAfter: true)
            } else if character.isWhitespace {
                appendCurrent()
            } else {
                currentText.append(character)
            }
        }

        appendCurrent()
        return words.isEmpty ? [MOTDWordToken(text: "Minecraft", colorCode: "b", bold: true), MOTDWordToken(text: "Server", colorCode: "f", bold: true)] : words
    }

    static func formattedString(from words: [MOTDWordToken]) -> String {
        var output = ""
        let visibleWords = words.filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        for (index, word) in visibleWords.enumerated() {
            output += "\u{00A7}\(word.colorCode)"
            if word.bold { output += "\u{00A7}l" }
            if word.italic { output += "\u{00A7}o" }
            if word.underlined { output += "\u{00A7}n" }
            output += word.text.trimmingCharacters(in: .whitespacesAndNewlines)

            if word.lineBreakAfter {
                output += "\n"
            } else if index != visibleWords.count - 1 {
                output += " "
            }
        }

        return output
    }
}

struct InfoLine: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}

struct MinecraftMOTDColor: Identifiable {
    let code: String
    let name: String
    let color: Color

    var id: String { code }

    static let defaultColor = MinecraftMOTDColor(code: "f", name: "White", color: .white)

    static let palette: [MinecraftMOTDColor] = [
        MinecraftMOTDColor(code: "0", name: "Black", color: Color(red: 0.00, green: 0.00, blue: 0.00)),
        MinecraftMOTDColor(code: "1", name: "Dark Blue", color: Color(red: 0.00, green: 0.00, blue: 0.67)),
        MinecraftMOTDColor(code: "2", name: "Dark Green", color: Color(red: 0.00, green: 0.67, blue: 0.00)),
        MinecraftMOTDColor(code: "3", name: "Dark Aqua", color: Color(red: 0.00, green: 0.67, blue: 0.67)),
        MinecraftMOTDColor(code: "4", name: "Dark Red", color: Color(red: 0.67, green: 0.00, blue: 0.00)),
        MinecraftMOTDColor(code: "5", name: "Dark Purple", color: Color(red: 0.67, green: 0.00, blue: 0.67)),
        MinecraftMOTDColor(code: "6", name: "Gold", color: Color(red: 1.00, green: 0.67, blue: 0.00)),
        MinecraftMOTDColor(code: "7", name: "Gray", color: Color(red: 0.67, green: 0.67, blue: 0.67)),
        MinecraftMOTDColor(code: "8", name: "Dark Gray", color: Color(red: 0.33, green: 0.33, blue: 0.33)),
        MinecraftMOTDColor(code: "9", name: "Blue", color: Color(red: 0.33, green: 0.33, blue: 1.00)),
        MinecraftMOTDColor(code: "a", name: "Green", color: Color(red: 0.33, green: 1.00, blue: 0.33)),
        MinecraftMOTDColor(code: "b", name: "Aqua", color: Color(red: 0.33, green: 1.00, blue: 1.00)),
        MinecraftMOTDColor(code: "c", name: "Red", color: Color(red: 1.00, green: 0.33, blue: 0.33)),
        MinecraftMOTDColor(code: "d", name: "Light Purple", color: Color(red: 1.00, green: 0.33, blue: 1.00)),
        MinecraftMOTDColor(code: "e", name: "Yellow", color: Color(red: 1.00, green: 1.00, blue: 0.33)),
        defaultColor
    ]

    static func color(for code: String) -> MinecraftMOTDColor {
        palette.first { $0.code == code } ?? defaultColor
    }
}

struct MOTDPreview: View {
    let text: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Preview")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(text.isEmpty ? "Minecraft Server" : text)
                .font(.system(.body, design: .monospaced))
                .fontWeight(.semibold)
                .foregroundStyle(color)
                .lineLimit(2)
                .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
                .padding(10)
                .background(Color.black)
                .cornerRadius(8)
        }
    }
}

struct PlayerListCard: View {
    let title: String
    let icon: String
    let players: [MinecraftPlayerRecord]
    let emptyText: String

    var body: some View {
        PanelCard(title, icon: icon) {
            if players.isEmpty {
                Text(emptyText)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 18)
            } else {
                VStack(spacing: 8) {
                    ForEach(players) { player in
                        HStack {
                            Image(systemName: "person.fill")
                                .foregroundStyle(Color.panelBlue)
                            Text(player.name)
                                .fontWeight(.medium)
                            Spacer()
                            if let level = player.level {
                                Text("Level \(level)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(10)
                        .background(Color.rowBackground)
                        .cornerRadius(8)
                    }
                }
            }
        }
    }
}

struct BackupsView: View {
    @ObservedObject var instance: ServerInstance
    @State private var isCreating = false
    @State private var confirmRestore: BackupRecord?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PageTitle(title: "Backups", subtitle: "World backups for \(instance.config.name)")

                HStack(spacing: 12) {
                    Button {
                        createBackup()
                    } label: {
                        if isCreating {
                            ProgressView().controlSize(.small).frame(width: 160)
                        } else {
                            Label("Create Backup Now", systemImage: "externaldrive.badge.clock")
                                .frame(width: 160)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.panelBlue)
                    .disabled(isCreating || !instance.isMinecraftServer)

                    Toggle("Auto-Backup", isOn: Binding(
                        get: { instance.backupEnabled },
                        set: { enabled in
                            instance.backupEnabled = enabled
                            if enabled { instance.startAutoBackupTimer() }
                            else { instance.stopAutoBackupTimer() }
                        }
                    ))
                    .disabled(!instance.isMinecraftServer)

                    if instance.backupEnabled {
                        Stepper("Every \(Int(instance.backupIntervalHours))h", value: Binding(
                            get: { instance.backupIntervalHours },
                            set: { h in
                                instance.backupIntervalHours = h
                                instance.startAutoBackupTimer()
                            }
                        ), in: 1...48)
                    }

                    Spacer()

                    Stepper("Keep: \(instance.maxBackups)", value: Binding(
                        get: { instance.maxBackups },
                        set: { instance.maxBackups = $0 }
                    ), in: 1...50)
                }

                if instance.backups.isEmpty {
                    PanelCard("No Backups", icon: "externaldrive") {
                        Text("No backups created yet. Click \"Create Backup Now\" to create your first backup.")
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 18)
                    }
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 340), spacing: 14)], spacing: 14) {
                        ForEach(instance.backups) { record in
                            BackupCard(record: record) {
                                confirmRestore = record
                            } delete: {
                                instance.deleteBackup(record)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .alert("Restore Backup", isPresented: Binding(
            get: { confirmRestore != nil },
            set: { if !$0 { confirmRestore = nil } }
        )) {
            Button("Cancel", role: .cancel) { confirmRestore = nil }
            Button("Restore", role: .destructive) {
                if let record = confirmRestore {
                    instance.restoreBackup(record)
                }
                confirmRestore = nil
            }
        } message: {
            if let record = confirmRestore {
                Text("Restore world \"\(record.worldName)\" from backup created \(record.formattedDate)? The current world will be replaced. The server must be stopped.")
            }
        }
    }

    private func createBackup() {
        isCreating = true
        DispatchQueue.global(qos: .userInitiated).async {
            instance.createBackup()
            DispatchQueue.main.async { isCreating = false }
        }
    }
}

struct BackupCard: View {
    let record: BackupRecord
    let restore: () -> Void
    let delete: () -> Void

    var body: some View {
        PanelCard(record.worldName, icon: "externaldrive") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    InfoLine(title: "Date", value: record.formattedDate)
                    Spacer()
                    InfoLine(title: "Size", value: record.formattedSize)
                }
                HStack(spacing: 10) {
                    Button {
                        restore()
                    } label: {
                        Label("Restore", systemImage: "arrow.uturn.backward")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)

                    Button(role: .destructive) {
                        delete()
                    } label: {
                        Label("Delete", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }
}

struct RemoteServersView: View {
    @ObservedObject var remoteManager: RemoteServerManager
    @State private var showingAdd = false
    @State private var selectedConfigID: UUID?
    @State private var remoteOutput = ""
    @State private var cmdText = ""
    @State private var connectionResult: String?

    private var selectedConfig: RemoteServerConfig? {
        remoteManager.configs.first { $0.id == selectedConfigID }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PageTitle(title: "Remote Servers", subtitle: "Manage servers over SSH")

                HStack(spacing: 10) {
                    Button {
                        showingAdd = true
                    } label: {
                        Label("Add Server", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.panelBlue)

                    if let config = selectedConfig {
                        Button {
                            testConn(config)
                        } label: {
                            Label("Test", systemImage: "bolt")
                        }
                        .buttonStyle(.bordered)

                        Button {
                            remoteManager.deleteConfig(config.id)
                            if selectedConfigID == config.id { selectedConfigID = remoteManager.configs.first?.id }
                        } label: {
                            Label("Remove", systemImage: "trash")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.bordered)
                    }

                    Spacer()

                    if selectedConfig == nil, !remoteManager.configs.isEmpty {
                        Text("Select a server below")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if remoteManager.configs.isEmpty {
                    PanelCard("No Remote Servers", icon: "antenna.radiowaves.left.and.right") {
                        VStack(spacing: 12) {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .font(.system(size: 36))
                                .foregroundColor(.panelBlue)
                            Text("Add your Oracle Cloud or Ubuntu server to manage it remotely.")
                                .foregroundStyle(.secondary)
                            Button {
                                showingAdd = true
                            } label: {
                                Label("Add Server", systemImage: "plus")
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 30)
                    }
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 340), spacing: 14)], spacing: 14) {
                        ForEach(remoteManager.configs) { config in
                            RemoteServerCard(
                                config: config,
                                status: remoteManager.status[config.id] ?? "Idle",
                                isSelected: selectedConfigID == config.id,
                                select: { selectedConfigID = config.id },
                                test: { testConn(config) }
                            )
                        }
                    }

                    if let config = selectedConfig {
                        PanelCard("Remote Console", icon: "terminal") {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    TextField("Command", text: $cmdText)
                                        .textFieldStyle(.roundedBorder)
                                        .onSubmit { sendCommand(config) }
                                    Button {
                                        sendCommand(config)
                                    } label: {
                                        Label("Run", systemImage: "paperplane")
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .disabled(cmdText.trimmingCharacters(in: .whitespaces).isEmpty)
                                }

                                ScrollView {
                                    Text(remoteOutput.isEmpty ? "Output appears here..." : remoteOutput)
                                        .font(.system(.callout, design: .monospaced))
                                        .foregroundStyle(.green)
                                        .textSelection(.enabled)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(8)
                                }
                                .frame(maxHeight: 200)
                                .background(Color.black)
                                .cornerRadius(8)

                                HStack {
                                    Button {
                                        remoteOutput = ""
                                    } label: {
                                        Label("Clear", systemImage: "trash")
                                            .controlSize(.small)
                                    }
                                    .buttonStyle(.bordered)

                                    Button {
                                        syncBackup(config)
                                    } label: {
                                        Label("Upload Backups", systemImage: "externaldrive")
                                            .controlSize(.small)
                                    }
                                    .buttonStyle(.bordered)

                                    Button {
                                        startRemoteServer(config)
                                    } label: {
                                        Label("Start Server", systemImage: "play")
                                            .controlSize(.small)
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(.green)

                                    Button {
                                        stopRemoteServer(config)
                                    } label: {
                                        Label("Stop Server", systemImage: "stop")
                                            .controlSize(.small)
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(.red)
                                }
                            }
                        }

                        if let result = connectionResult {
                            PanelCard("Connection Info", icon: "info.circle") {
                                Text(result)
                                    .font(.system(.callout, design: .monospaced))
                                    .textSelection(.enabled)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .sheet(isPresented: $showingAdd) {
            AddRemoteServerSheet(remoteManager: remoteManager)
        }
    }

    private func testConn(_ config: RemoteServerConfig) {
        remoteOutput = ""
        connectionResult = nil
        remoteManager.testConnection(config) { success, output in
            connectionResult = output
            remoteOutput = output
        }
    }

    private func sendCommand(_ config: RemoteServerConfig) {
        let cmd = cmdText.trimmingCharacters(in: .whitespaces)
        guard !cmd.isEmpty else { return }
        remoteManager.runSSH(config, command: cmd) { output in
            remoteOutput += output
        }
        cmdText = ""
    }

    private func syncBackup(_ config: RemoteServerConfig) {
        let remotePath = "\(config.serverPath)/Backups"
        remoteManager.runSSH(config, command: "mkdir -p '\(remotePath)'")
        remoteManager.runSSH(config, command: "ls -lh '\(remotePath)'") { output in
            remoteOutput += "[Sync] Backups on \(config.name):\n\(output)"
        }
    }

    private func startRemoteServer(_ config: RemoteServerConfig) {
        let startCmd: String
        if config.serverPath.contains("minecraft") {
            startCmd = "cd '\(config.serverPath)' && screen -dmS mc java -Xmx4G -jar server.jar nogui"
        } else {
            startCmd = "cd '\(config.serverPath)' && screen -dmS mc ./start.sh"
        }
        remoteManager.runSSH(config, command: startCmd) { output in
            remoteOutput += output
        }
        remoteOutput += "[Remote] Starting server on \(config.name)...\n"
    }

    private func stopRemoteServer(_ config: RemoteServerConfig) {
        remoteManager.runSSH(config, command: "screen -S mc -X stuff 'stop\\n'") { output in
            remoteOutput += output
        }
        remoteOutput += "[Remote] Stopping server on \(config.name)...\n"
    }

}

struct RemoteServerCard: View {
    let config: RemoteServerConfig
    let status: String
    let isSelected: Bool
    let select: () -> Void
    let test: () -> Void

    var body: some View {
        PanelCard(config.name, icon: config.isOracle ? "cloud" : "laptopcomputer") {
            VStack(alignment: .leading, spacing: 8) {
                InfoLine(title: "Host", value: "\(config.username)@\(config.host):\(config.port)")
                InfoLine(title: "Server Path", value: config.serverPath)
                InfoLine(title: "Status", value: status)

                HStack(spacing: 8) {
                    Button {
                        select()
                    } label: {
                        Label("Select", systemImage: isSelected ? "checkmark.circle.fill" : "circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(isSelected ? .panelBlue : .secondary)
                    .controlSize(.small)

                    Button {
                        test()
                    } label: {
                        Label("Test SSH", systemImage: "bolt")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
    }
}

struct AddRemoteServerSheet: View {
    @ObservedObject var remoteManager: RemoteServerManager
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var host = ""
    @State private var port = "22"
    @State private var username = "ubuntu"
    @State private var keyPath = ""
    @State private var serverPath = "/home/ubuntu"
    @State private var isOracle = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Add Remote Server")
                .font(.headline)

            LabeledTextField(title: "Name", text: $name)
            LabeledTextField(title: "Host", text: $host)
            LabeledTextField(title: "Port", text: $port)
            LabeledTextField(title: "Username", text: $username)
            VStack(alignment: .leading, spacing: 5) {
                Text("SSH Key Path")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    TextField("~/.ssh/id_rsa", text: $keyPath)
                        .textFieldStyle(.roundedBorder)
                    Button {
                        chooseKey()
                    } label: {
                        Label("Browse", systemImage: "folder")
                    }
                    .buttonStyle(.bordered)
                }
            }
            LabeledTextField(title: "Server Path", text: $serverPath)
            Toggle("Oracle Cloud", isOn: $isOracle)

            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)
                Spacer()
                Button("Add") {
                    let cfg = RemoteServerConfig(
                        name: name, host: host,
                        port: Int(port) ?? 22,
                        username: username,
                        keyPath: keyPath,
                        serverPath: serverPath,
                        isOracle: isOracle
                    )
                    remoteManager.addConfig(cfg)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || host.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 420)
        .onAppear {
            if keyPath.isEmpty {
                let home = FileManager.default.homeDirectoryForCurrentUser.path
                let candidates = ["\(home)/.ssh/id_ed25519", "\(home)/.ssh/id_rsa", "\(home)/.ssh/oracle.key"]
                keyPath = candidates.first { FileManager.default.fileExists(atPath: $0) } ?? ""
            }
        }
    }

    private func chooseKey() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            keyPath = url.path
        }
    }
}

struct UpdatesView: View {
    @ObservedObject var instance: ServerInstance
    @State private var updateCheck: ServerInstance.ServerUpdateCheck?
    @State private var isLoading = false
    @State private var isUpdating = false
    @State private var message = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PageTitle(title: "Updates", subtitle: instance.isMinecraftServer ? "Check for new server software versions" : "Updates are available for Minecraft servers")

                if !instance.isMinecraftServer {
                    PanelCard("Not Available", icon: "arrow.up.circle") {
                        Text("Server updates are only available for Minecraft servers.")
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 18)
                    }
                } else if isLoading {
                    PanelCard("Checking...", icon: "arrow.clockwise") {
                        HStack {
                            ProgressView()
                                .controlSize(.small)
                            Text("Checking for updates...")
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 18)
                    }
                } else if let check = updateCheck {
                    PanelCard("Version Status", icon: "shippingbox") {
                        VStack(alignment: .leading, spacing: 12) {
                            InfoLine(title: "Current", value: check.currentVersion)
                            InfoLine(title: "Latest", value: check.latestVersion)

                            if check.isUpToDate {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                    Text("Your server is up to date!")
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.top, 6)
                            } else {
                                HStack {
                                    Image(systemName: "arrow.up.circle.fill")
                                        .foregroundStyle(.orange)
                                    Text("A newer version is available")
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.top, 6)

                                Button {
                                    runUpdate(check)
                                } label: {
                                    if isUpdating {
                                        ProgressView().controlSize(.small).frame(width: 160)
                                    } else {
                                        Label("Update to \(check.latestVersion)", systemImage: "arrow.up.circle")
                                            .frame(width: 200)
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.panelBlue)
                                .disabled(isUpdating || instance.isRunning)
                            }
                        }
                    }
                } else {
                    PanelCard("No Update Info", icon: "arrow.up.circle") {
                        VStack(spacing: 12) {
                            Text("Click check to scan for updates.")
                                .foregroundStyle(.secondary)
                            Button {
                                checkForUpdates()
                            } label: {
                                Label("Check for Updates", systemImage: "arrow.clockwise")
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.vertical, 18)
                    }
                }

                if !message.isEmpty {
                    Text(message)
                        .font(.callout)
                        .foregroundStyle(message.contains("failed") || message.contains("Error") ? .red : .secondary)
                }

                if updateCheck == nil && !isLoading {
                    Button {
                        checkForUpdates()
                    } label: {
                        Label("Check for Updates", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.panelBlue)
                    .disabled(instance.isRunning)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .onAppear {
            if updateCheck == nil { checkForUpdates() }
        }
    }

    private func checkForUpdates() {
        isLoading = true
        message = ""
        Task {
            let result = await instance.checkForUpdates()
            await MainActor.run {
                updateCheck = result
                isLoading = false
                if let r = result, r.isUpToDate {
                    message = "Server is up to date (\(r.latestVersion))."
                }
            }
        }
    }

    private func runUpdate(_ check: ServerInstance.ServerUpdateCheck) {
        isUpdating = true
        message = ""
        Task {
            do {
                try await instance.performUpdate(check)
                await MainActor.run {
                    isUpdating = false
                    message = "Update complete! Select the new version in Options."
                    updateCheck = nil
                }
            } catch {
                await MainActor.run {
                    isUpdating = false
                    message = "Update failed: \(error.localizedDescription)"
                }
            }
        }
    }
}

struct ModrinthProject: Identifiable, Decodable {
    let id: String
    let title: String
    let description: String
    let slug: String
    let projectType: String
    let clientSide: String
    let serverSide: String
    let latestVersion: String

    enum CodingKeys: String, CodingKey {
        case id, title, description, slug, projectType = "project_type", clientSide = "client_side", serverSide = "server_side", latestVersion = "latest_version"
    }
}

struct CuratedMod: Identifiable {
    let id: String
    let title: String
    let description: String
    let modrinthProject: String
    let loader: String
}

let curatedMods = [
    CuratedMod(id: "lithium", title: "Lithium", description: "Server-side physics/AI/redstone. Huge TPS boost, Forge + Fabric.", modrinthProject: "lithium", loader: "Forge + Fabric"),
    CuratedMod(id: "starlight", title: "Starlight", description: "Faster lighting engine. Forge + Fabric.", modrinthProject: "starlight", loader: "Forge + Fabric"),
    CuratedMod(id: "ferritecore", title: "FerriteCore", description: "Reduces RAM usage. Forge + Fabric.", modrinthProject: "ferrite-core", loader: "Forge + Fabric"),
    CuratedMod(id: "modernfix", title: "ModernFix", description: "Fixes performance, reduces RAM, faster startup. Forge + Fabric.", modrinthProject: "modernfix", loader: "Forge + Fabric"),
    CuratedMod(id: "krypton", title: "Krypton", description: "Networking optimization. Fabric.", modrinthProject: "krypton", loader: "Fabric"),
    CuratedMod(id: "c2me", title: "C2ME", description: "Chunk loading optimization. Fabric.", modrinthProject: "c2me-fabric", loader: "Fabric"),
]

private struct ModVersion: Decodable {
    let files: [ModFile]
    let versionNumber: String
    let gameVersions: [String]
    let loaders: [String]?
    enum CodingKeys: String, CodingKey {
        case files; case versionNumber = "version_number"; case gameVersions = "game_versions"; case loaders
    }
}

private struct ModFile: Decodable { let url: String; let filename: String }

struct ModsView: View {
    @ObservedObject var instance: ServerInstance
    @State private var mods: [ServerInstance.ModEntry] = []
    @State private var message = ""
    @State private var searchQuery = ""
    @State private var searchResults: [ModrinthProject] = []
    @State private var isSearching = false
    @State private var downloadingModID: String?
    @State private var activeTab = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    PageTitle(title: "Mods & Plugins", subtitle: "\(instance.serverPath)/mods folder")
                    Spacer()
                    Menu {
                        Button("Open Mods Folder") { instance.openFile("\(instance.serverPath)/mods") }
                        Button("Open server.jar folder") { instance.openServerFolder() }
                    } label: {
                        Label("More", systemImage: "ellipsis.circle")
                    }
                    .buttonStyle(.bordered)
                }

                Picker("", selection: $activeTab) {
                    Text("Installed (\(mods.count))").tag(0)
                    Text("Browse Modrinth").tag(1)
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                if activeTab == 0 {
                    installedModsSection
                } else {
                    browseSection
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .onAppear { refreshMods() }
    }

    // MARK: - Installed Mods Tab
    private var installedModsSection: some View {
        VStack(spacing: 14) {
            if !message.isEmpty {
                Text(message).font(.callout).foregroundStyle(.secondary)
            }

            if mods.isEmpty {
                PanelCard("Installed Mods", icon: "puzzlepiece.extension") {
                    VStack(spacing: 12) {
                        Image(systemName: "puzzlepiece.extension").font(.system(size: 32)).foregroundColor(.panelBlue)
                        Text("No mods found.").foregroundStyle(.secondary)
                        Text("Switch to Browse tab to install optimization mods from Modrinth.").font(.caption).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 30)
                }
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 340), spacing: 14)], spacing: 14) {
                    ForEach(mods) { mod in
                        PanelCard(mod.fileName, icon: mod.isEnabled ? "puzzlepiece.extension.fill" : "puzzlepiece.extension") {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    InfoLine(title: "Status", value: mod.isEnabled ? "Enabled" : "Disabled")
                                    Spacer()
                                    InfoLine(title: "Size", value: mod.formattedSize)
                                }
                                HStack(spacing: 10) {
                                    Button {
                                        instance.toggleMod(mod); refreshMods()
                                    } label: {
                                        Label(mod.isEnabled ? "Disable" : "Enable", systemImage: mod.isEnabled ? "stop.circle" : "play.circle").frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(.bordered).tint(mod.isEnabled ? .orange : .green)

                                    Button(role: .destructive) {
                                        instance.deleteMod(mod); refreshMods()
                                    } label: {
                                        Label("Delete", systemImage: "trash").frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                        }
                    }
                }
            }

            Button {
                instance.openFile("\(instance.serverPath)/mods")
            } label: {
                Label("Open Mods Folder in Finder", systemImage: "folder")
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - Browse Tab
    private var browseSection: some View {
        VStack(spacing: 14) {
            if !message.isEmpty {
                Text(message).font(.callout).foregroundStyle(.secondary)
            }

            PanelCard("Recommended Forge Mods", icon: "star") {
                Text("One-click install. These boost server performance without players needing to install anything.")
                    .font(.caption).foregroundStyle(.secondary).padding(.bottom, 6)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 8)], spacing: 8) {
                    ForEach(curatedMods.filter { $0.loader.contains("Forge") }) { mod in
                        curatedModRow(mod)
                    }
                }
            }

            PanelCard("Recommended Fabric Mods", icon: "star") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 8)], spacing: 8) {
                    ForEach(curatedMods.filter { !$0.loader.contains("Forge") }) { mod in
                        curatedModRow(mod)
                    }
                }
            }

            PanelCard("Search Modrinth", icon: "magnifyingglass") {
                VStack(spacing: 10) {
                    HStack(spacing: 8) {
                        TextField("Search mods by name...", text: $searchQuery)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit { searchMods() }
                        Button {
                            searchMods()
                        } label: {
                            Label("Search", systemImage: "magnifyingglass")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(searchQuery.trimmingCharacters(in: .whitespaces).isEmpty || isSearching)
                    }

                    if isSearching {
                        HStack { ProgressView().controlSize(.small); Text("Searching Modrinth...").font(.caption).foregroundStyle(.secondary) }
                    }

                    if !searchResults.isEmpty {
                        ForEach(searchResults) { project in
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(project.title).fontWeight(.semibold)
                                    Text(project.description).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)

                                if project.serverSide == "required" || project.serverSide == "optional" {
                                    Button {
                                        downloadProject(project)
                                    } label: {
                                        if downloadingModID == project.id {
                                            ProgressView().controlSize(.small).frame(width: 70)
                                        } else {
                                            Label("Install", systemImage: "plus").frame(width: 70)
                                        }
                                    }
                                    .buttonStyle(.borderedProminent).controlSize(.small)
                                    .disabled(downloadingModID != nil)
                                } else {
                                    Text("Client").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            .padding(8).background(Color.rowBackground).cornerRadius(6)
                        }
                    } else if !isSearching && !message.isEmpty {
                        Text("No results or API unavailable.\nTry the recommended mods above.").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func curatedModRow(_ mod: CuratedMod) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(mod.title).font(.callout).fontWeight(.semibold)
                Text(mod.description).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                downloadCuratedMod(mod)
            } label: {
                if downloadingModID == mod.id {
                    ProgressView().controlSize(.mini).frame(width: 50)
                } else {
                    Label("Get", systemImage: "plus").frame(width: 50)
                }
            }
            .buttonStyle(.borderedProminent).controlSize(.small)
            .disabled(downloadingModID != nil)
        }
        .padding(8).background(Color.rowBackground).cornerRadius(6)
    }

    private func refreshMods() { mods = instance.listMods() }

    private var serverMCVersion: String {
        instance.selectedLaunchProfile?.minecraftVersion ?? ""
    }

    private var serverAcceptedLoaders: [String] {
        guard let profile = instance.selectedLaunchProfile else { return [] }
        if profile.loader.contains("Forge") { return ["forge"] }
        let jarName = profile.id.lowercased()
        if jarName.contains("fabric") { return ["fabric", "quilt"] }
        return []
    }

    private func matchModVersion(_ allVersions: [ModVersion], targetVersion: String, loaders: [String]) -> ModVersion? {
        let loadersSet = Set(loaders)
        let matchesLoader = { (v: ModVersion) -> Bool in
            guard let versionLoaders = v.loaders else { return true }
            return !Set(versionLoaders).isDisjoint(with: loadersSet)
        }
        let exact = allVersions.first { v in
            v.gameVersions.contains(targetVersion) && matchesLoader(v)
        }
        if let found = exact { return found }
        let partial = allVersions.first { v in
            v.gameVersions.contains { targetVersion.hasPrefix($0) || $0.hasPrefix(targetVersion) }
            && matchesLoader(v)
        }
        if let found = partial { return found }
        return allVersions.first { matchesLoader($0) }
    }

    private func downloadCuratedMod(_ curated: CuratedMod) {
        downloadingModID = curated.id
        message = ""
        let targetVersion = serverMCVersion
        let loaders = serverAcceptedLoaders
        guard !loaders.isEmpty else {
            message = "Server does not support mods."
            downloadingModID = nil
            return
        }
        Task {
            do {
                guard let url = URL(string: "https://api.modrinth.com/v2/project/\(curated.modrinthProject)/version") else {
                    throw URLError(.badURL) }
                let (data, response) = try await ServerManager.urlSession.data(from: url)
                guard let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 else {
                    throw URLError(.badServerResponse) }

                let allVersions = try JSONDecoder().decode([ModVersion].self, from: data)
                guard let matched = matchModVersion(allVersions, targetVersion: targetVersion, loaders: loaders) else {
                    throw URLError(.fileDoesNotExist) }
                guard let file = matched.files.first else { throw URLError(.fileDoesNotExist) }

                let jarData = try await Self.downloadFile(from: file.url)
                try FileManager.default.createDirectory(atPath: "\(instance.serverPath)/mods", withIntermediateDirectories: true)
                try jarData.write(to: URL(fileURLWithPath: "\(instance.serverPath)/mods/\(file.filename)"))
                await MainActor.run {
                    downloadingModID = nil
                    message = "Installed \(curated.title) v\(matched.versionNumber)"
                    refreshMods()
                }
            } catch {
                await MainActor.run { downloadingModID = nil; message = "Failed: \(error.localizedDescription)" }
            }
        }
    }

    private static func downloadFile(from urlString: String) async throws -> Data {
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        let (data, _) = try await ServerManager.urlSession.data(from: url)
        return data
    }

    private func searchMods() {
        let query = searchQuery.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return }
        isSearching = true; searchResults = []; message = ""
        Task {
            do {
                let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
                guard let url = URL(string: "https://api.modrinth.com/v2/search?query=\(encoded)&limit=20") else { return }
                let (data, _) = try await ServerManager.urlSession.data(from: url)
                struct SearchResult: Decodable { let hits: [ModrinthProject] }
                let result = try JSONDecoder().decode(SearchResult.self, from: data)
                await MainActor.run { searchResults = result.hits; isSearching = false }
            } catch {
                await MainActor.run { isSearching = false; message = "Search unavailable: \(error.localizedDescription)" }
            }
        }
    }

    private func downloadProject(_ project: ModrinthProject) {
        downloadingModID = project.id; message = ""
        let targetVersion = serverMCVersion
        let loaders = serverAcceptedLoaders
        guard !loaders.isEmpty else {
            message = "Server does not support mods."
            downloadingModID = nil
            return
        }
        Task {
            do {
                guard let url = URL(string: "https://api.modrinth.com/v2/project/\(project.id)/version") else {
                    throw URLError(.badURL) }
                let (data, response) = try await ServerManager.urlSession.data(from: url)
                guard let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 else {
                    throw URLError(.badServerResponse) }

                let allVersions = try JSONDecoder().decode([ModVersion].self, from: data)
                guard let matched = matchModVersion(allVersions, targetVersion: targetVersion, loaders: loaders) else {
                    throw URLError(.fileDoesNotExist) }
                guard let file = matched.files.first else { throw URLError(.fileDoesNotExist) }

                let jarData = try await Self.downloadFile(from: file.url)
                try FileManager.default.createDirectory(atPath: "\(instance.serverPath)/mods", withIntermediateDirectories: true)
                try jarData.write(to: URL(fileURLWithPath: "\(instance.serverPath)/mods/\(file.filename)"))
                await MainActor.run {
                    downloadingModID = nil
                    message = "Installed \(project.title) v\(matched.versionNumber)"
                    refreshMods()
                }
            } catch {
                await MainActor.run { downloadingModID = nil; message = "Failed: \(error.localizedDescription)" }
            }
        }
    }
}

struct FileShortcutCard: View {
    let title: String
    let detail: String
    let icon: String
    let open: () -> Void

    var body: some View {
        PanelCard(title, icon: icon) {
            HStack {
                Text(detail)
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                Button(action: open) {
                    Label("Open", systemImage: "arrow.up.forward.app")
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

extension Color {
    static let panelBlue = Color(red: 0.05, green: 0.36, blue: 0.72)
    static let panelBackground = Color(nsColor: .windowBackgroundColor)
    static let sidebarBackground = Color(nsColor: .controlBackgroundColor)
    static let cardBackground = Color(nsColor: .controlBackgroundColor)
    static let rowBackground = Color(nsColor: .controlBackgroundColor).opacity(0.7)
    static let cardStroke = Color(nsColor: .separatorColor).opacity(0.4)
}
