import Foundation
import AppKit
import UserNotifications

struct MinecraftVersionSummary: Decodable, Identifiable, Hashable {
    let id: String
    let type: String
    let url: String
}

struct ForgeVersionSummary: Identifiable, Hashable {
    let id: String
    let minecraftVersion: String
    let forgeVersion: String
    let installerURL: String

    var displayName: String {
        "\(minecraftVersion) - Forge \(forgeVersion)"
    }
}

private struct MinecraftVersionManifest: Decodable {
    let versions: [MinecraftVersionSummary]
}

private struct MinecraftVersionDetails: Decodable {
    struct Downloads: Decodable {
        struct Download: Decodable {
            let url: String
        }

        let server: Download?
    }

    let downloads: Downloads
}

enum ServerSetupError: LocalizedError {
    case invalidPath
    case invalidVersion
    case missingServerDownload
    case badServerResponse
    case missingJava(Int)
    case forgeInstallFailed(String)
    case missingSteamCMD
    case steamCMDInstallFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidPath:
            return "Server path is empty."
        case .invalidVersion:
            return "No Minecraft version was selected."
        case .missingServerDownload:
            return "This Minecraft version does not include a server download."
        case .badServerResponse:
            return "The server download failed."
        case .missingJava(let version):
            return "Java \(version)+ is required but was not found."
        case .forgeInstallFailed(let output):
            if output.isEmpty {
                return "Forge installer failed."
            }
            return "Forge installer failed: \(output)"
        case .missingSteamCMD:
            return "SteamCMD was not found. Install it with Homebrew first: brew install steamcmd"
        case .steamCMDInstallFailed(let output):
            if output.isEmpty {
                return "SteamCMD install failed."
            }
            return "SteamCMD install failed: \(output)"
        }
    }
}

private final class ForgeMetadataParser: NSObject, XMLParserDelegate {
    private var currentElement = ""
    private var currentText = ""
    var versions: [String] = []

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        currentElement = elementName
        currentText = ""
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "version" {
            let trimmedVersion = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedVersion.isEmpty {
                versions.append(trimmedVersion)
            }
        }
        currentElement = ""
        currentText = ""
    }
}

struct MinecraftPlayerRecord: Codable, Identifiable {
    let uuid: String
    let name: String
    let level: Int?
    let bypassesPlayerLimit: Bool?

    var id: String { uuid.isEmpty ? name : uuid }
}

struct ServerLaunchProfile: Identifiable, Hashable {
    let id: String
    let displayName: String
    let minecraftVersion: String
    let loader: String
    let arguments: [String]
    let detail: String
}

struct SteamCMDInstallPreset: Hashable {
    let appID: Int
    let platform: String?
    let executableRelativePath: String
    let launchArguments: String
    let port: String
    let note: String
}

enum GameServerKind: String, CaseIterable, Codable, Identifiable, Hashable {
    case minecraft
    case counterStrike2
    case arkSurvivalAscended
    case arkSurvivalEvolved
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .minecraft: return "Minecraft"
        case .counterStrike2: return "Counter-Strike 2"
        case .arkSurvivalAscended: return "ARK: Survival Ascended"
        case .arkSurvivalEvolved: return "ARK: Survival Evolved"
        case .custom: return "Custom Game"
        }
    }

    var icon: String {
        switch self {
        case .minecraft: return "cube.fill"
        case .counterStrike2: return "scope"
        case .arkSurvivalAscended, .arkSurvivalEvolved: return "mountain.2.fill"
        case .custom: return "gamecontroller.fill"
        }
    }

    var defaultFolderName: String {
        switch self {
        case .minecraft: return "minecraft-server"
        case .counterStrike2: return "counter-strike-2-server"
        case .arkSurvivalAscended: return "ark-ascended-server"
        case .arkSurvivalEvolved: return "ark-evolved-server"
        case .custom: return "game-server"
        }
    }

    var defaultPort: String {
        switch self {
        case .minecraft: return "25565"
        case .counterStrike2: return "27015"
        case .arkSurvivalAscended: return "7777"
        case .arkSurvivalEvolved: return "7777"
        case .custom: return "27015"
        }
    }

    var steamCMDPreset: SteamCMDInstallPreset? {
        switch self {
        case .minecraft, .custom:
            return nil
        case .counterStrike2:
            return SteamCMDInstallPreset(
                appID: 730,
                platform: "linux",
                executableRelativePath: "game/cs2.sh",
                launchArguments: "-dedicated +map de_dust2 -port 27015",
                port: "27015",
                note: "CS2 dedicated server uses Steam app 730 and ships for Windows/Linux. Running it on macOS usually needs a Linux host or container."
            )
        case .arkSurvivalEvolved:
            return SteamCMDInstallPreset(
                appID: 376030,
                platform: "linux",
                executableRelativePath: "ShooterGame/Binaries/Linux/ShooterGameServer",
                launchArguments: "TheIsland?listen?SessionName=ARK Server?ServerPassword=?ServerAdminPassword=admin -server -log",
                port: "7777",
                note: "ARK: Survival Evolved dedicated server uses Steam app 376030. The server package is Windows/Linux, not native macOS."
            )
        case .arkSurvivalAscended:
            return SteamCMDInstallPreset(
                appID: 2430930,
                platform: "windows",
                executableRelativePath: "ShooterGame/Binaries/Win64/ArkAscendedServer.exe",
                launchArguments: "TheIsland_WP?listen?SessionName=ARK Ascended Server?ServerAdminPassword=admin -server -log",
                port: "7777",
                note: "ARK: Survival Ascended dedicated server uses Steam app 2430930 and is currently Windows-only."
            )
        }
    }
}

struct BackupRecord: Identifiable, Codable, Hashable {
    let id: UUID
    let date: Date
    let fileName: String
    let fileSize: Int64
    let worldName: String

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }
}

struct ServerConfiguration: Identifiable, Codable, Hashable {
    let id: UUID
    var gameKind: GameServerKind = .minecraft
    var name: String
    var serverPath: String
    var customExecutablePath: String = ""
    var customLaunchArguments: String = ""
    var customServerPort: String = ""
    var propertiesFile: String { "\(serverPath)/server.properties" }
    var jvmArgsFile: String { "\(serverPath)/user_jvm_args.txt" }
    var opsFile: String { "\(serverPath)/ops.json" }
    var whitelistFile: String { "\(serverPath)/whitelist.json" }
    var publicJoinAddress: String = ""
    var playitTargetAddress: String = ""
    var selectedLaunchProfileID: String = ""
    var autoRestart: Bool = false
    var autoScaleEnabled: Bool = false
    var backupEnabled: Bool = false
    var backupIntervalHours: Double = 6
    var maxBackups: Int = 10

    init(id: UUID = UUID(), name: String, serverPath: String) {
        self.id = id
        self.name = name
        self.serverPath = serverPath
    }

    enum CodingKeys: String, CodingKey {
        case id
        case gameKind
        case name
        case serverPath
        case customExecutablePath
        case customLaunchArguments
        case customServerPort
        case publicJoinAddress
        case playitTargetAddress
        case selectedLaunchProfileID
        case autoRestart
        case autoScaleEnabled
        case backupEnabled
        case backupIntervalHours
        case maxBackups
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        gameKind = try container.decodeIfPresent(GameServerKind.self, forKey: .gameKind) ?? .minecraft
        name = try container.decode(String.self, forKey: .name)
        serverPath = try container.decode(String.self, forKey: .serverPath)
        customExecutablePath = try container.decodeIfPresent(String.self, forKey: .customExecutablePath) ?? ""
        customLaunchArguments = try container.decodeIfPresent(String.self, forKey: .customLaunchArguments) ?? ""
        customServerPort = try container.decodeIfPresent(String.self, forKey: .customServerPort) ?? ""
        publicJoinAddress = try container.decodeIfPresent(String.self, forKey: .publicJoinAddress) ?? "wine-google.gl.joinmc.link"
        playitTargetAddress = try container.decodeIfPresent(String.self, forKey: .playitTargetAddress) ?? "wine-google.gl.at.ply.gg:28984"
        selectedLaunchProfileID = try container.decodeIfPresent(String.self, forKey: .selectedLaunchProfileID) ?? ""
        autoRestart = try container.decodeIfPresent(Bool.self, forKey: .autoRestart) ?? false
        autoScaleEnabled = try container.decodeIfPresent(Bool.self, forKey: .autoScaleEnabled) ?? false
        backupEnabled = try container.decodeIfPresent(Bool.self, forKey: .backupEnabled) ?? false
        backupIntervalHours = try container.decodeIfPresent(Double.self, forKey: .backupIntervalHours) ?? 6
        maxBackups = try container.decodeIfPresent(Int.self, forKey: .maxBackups) ?? 10
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(gameKind, forKey: .gameKind)
        try container.encode(name, forKey: .name)
        try container.encode(serverPath, forKey: .serverPath)
        try container.encode(customExecutablePath, forKey: .customExecutablePath)
        try container.encode(customLaunchArguments, forKey: .customLaunchArguments)
        try container.encode(customServerPort, forKey: .customServerPort)
        try container.encode(publicJoinAddress, forKey: .publicJoinAddress)
        try container.encode(playitTargetAddress, forKey: .playitTargetAddress)
        try container.encode(selectedLaunchProfileID, forKey: .selectedLaunchProfileID)
        try container.encode(autoRestart, forKey: .autoRestart)
        try container.encode(autoScaleEnabled, forKey: .autoScaleEnabled)
        try container.encode(backupEnabled, forKey: .backupEnabled)
        try container.encode(backupIntervalHours, forKey: .backupIntervalHours)
        try container.encode(maxBackups, forKey: .maxBackups)
    }
}

class ServerInstance: ObservableObject, Identifiable {
    @Published var config: ServerConfiguration {
        didSet {
            DispatchQueue.main.async { [weak self] in
                self?.onConfigChanged?()
            }
        }
    }
    @Published var isRunning = false
    @Published var logOutput = ""
    @Published var networkLog = ""
    @Published var tunnelURL: String = "Check your Playit account"
    @Published var ramGB: Int = 4
    @Published var cpuThreads: Int = 1
    @Published var cpuUsagePercent: Double = 0
    @Published var ramUsageMB: Double = 0
    @Published var properties: [String: String] = [:]
    @Published var ops: [MinecraftPlayerRecord] = []
    @Published var whitelist: [MinecraftPlayerRecord] = []
    @Published var lastSavedMessage = ""
    @Published var launchProfiles: [ServerLaunchProfile] = []
    @Published var backups: [BackupRecord] = []
    @Published var crashCount = 0
    
    var autoRestart: Bool {
        get { config.autoRestart }
        set { var c = config; c.autoRestart = newValue; config = c }
    }
    var autoScaleEnabled: Bool {
        get { config.autoScaleEnabled }
        set { var c = config; c.autoScaleEnabled = newValue; config = c }
    }
    var backupEnabled: Bool {
        get { config.backupEnabled }
        set { var c = config; c.backupEnabled = newValue; config = c }
    }
    var backupIntervalHours: Double {
        get { config.backupIntervalHours }
        set { var c = config; c.backupIntervalHours = newValue; config = c }
    }
    var maxBackups: Int {
        get { config.maxBackups }
        set { var c = config; c.maxBackups = newValue; config = c }
    }
    
    var onConfigChanged: (() -> Void)?
    
    private var process: Process?
    private var tunnelProcess: Process?
    private var usageTimer: Timer?
    private var backupTimer: Timer?
    private var logFlushTimer: Timer?
    private var logBuffer = ""
    private var inputPipe = Pipe()
    private var startTime: Date?
    private var lastRestartAttempt: Date?
    private let restartCooldown: TimeInterval = 30
    
    var id: UUID { config.id }
    
    var serverPath: String { config.serverPath }
    var propertiesFile: String { config.propertiesFile }
    var jvmArgsFile: String { config.jvmArgsFile }
    var opsFile: String { config.opsFile }
    var whitelistFile: String { config.whitelistFile }
    var publicJoinAddress: String { config.publicJoinAddress }
    var playitTargetAddress: String { config.playitTargetAddress }
    var backupsDir: String { "\(serverPath)/Backups" }
    var backupsFile: String { "\(backupsDir)/backups.json" }

    var selectedLaunchProfile: ServerLaunchProfile? {
        launchProfiles.first { $0.id == config.selectedLaunchProfileID } ?? launchProfiles.first
    }

    var isMinecraftServer: Bool {
        config.gameKind == .minecraft
    }

    var canAttemptStart: Bool {
        isMinecraftServer ? selectedLaunchProfile != nil : true
    }

    var softwareName: String {
        if isMinecraftServer {
            return selectedLaunchProfile?.displayName ?? "No server version"
        }
        return config.gameKind.displayName
    }

    init(config: ServerConfiguration) {
        self.config = config
        self.cpuThreads = max(1, ProcessInfo.processInfo.processorCount)
        loadAllSettings()
        loadBackups()
    }

    func loadAllSettings() {
        if isMinecraftServer {
            refreshLaunchProfiles()
        } else {
            launchProfiles = []
        }
        if let content = try? String(contentsOfFile: jvmArgsFile, encoding: .utf8) {
            if let range = content.range(of: #"-Xmx(\d+)G"#, options: .regularExpression) {
                let val = content[range].replacingOccurrences(of: "-Xmx", with: "").replacingOccurrences(of: "G", with: "")
                self.ramGB = Int(val) ?? 4
            }
            if let range = content.range(of: #"-XX:ActiveProcessorCount=(\d+)"#, options: .regularExpression) {
                let val = content[range].replacingOccurrences(of: "-XX:ActiveProcessorCount=", with: "")
                self.cpuThreads = min(max(Int(val) ?? ServerInstance.maxCPUThreads, 1), ServerInstance.maxCPUThreads)
            } else {
                self.cpuThreads = ServerInstance.maxCPUThreads
            }
        }
        if let content = try? String(contentsOfFile: propertiesFile, encoding: .utf8) {
            var props: [String: String] = [:]
            content.components(separatedBy: .newlines).forEach { line in
                if !line.hasPrefix("#") && line.contains("=") {
                    let parts = line.components(separatedBy: "=")
                    if parts.count >= 2 { props[parts[0]] = parts.dropFirst().joined(separator: "=") }
                }
            }
            self.properties = props
        }
        loadPlayers()
    }

    func refreshLaunchProfiles() {
        let discoveredProfiles = discoverLaunchProfiles()
        launchProfiles = discoveredProfiles

        if !discoveredProfiles.contains(where: { $0.id == config.selectedLaunchProfileID }) {
            var newConfig = config
            newConfig.selectedLaunchProfileID = discoveredProfiles.first?.id ?? ""
            config = newConfig
        }
    }

    private func discoverLaunchProfiles() -> [ServerLaunchProfile] {
        ServerInstance.discoverLaunchProfiles(in: serverPath)
    }

    static func discoverLaunchProfiles(in serverPath: String) -> [ServerLaunchProfile] {
        var profiles: [ServerLaunchProfile] = []
        let fileManager = FileManager.default
        let normalizedPath = normalizedServerPath(serverPath)
        guard !normalizedPath.isEmpty else { return [] }

        let forgeRoot = URL(fileURLWithPath: normalizedPath)
            .appendingPathComponent("libraries/net/minecraftforge/forge")

        if let forgeVersions = try? fileManager.contentsOfDirectory(at: forgeRoot, includingPropertiesForKeys: nil) {
            for versionURL in forgeVersions {
                let argsURL = versionURL.appendingPathComponent("unix_args.txt")
                guard fileManager.fileExists(atPath: argsURL.path) else { continue }

                let versionName = versionURL.lastPathComponent
                let parts = versionName.split(separator: "-", maxSplits: 1).map(String.init)
                let minecraftVersion = parts.first ?? versionName
                let forgeVersion = parts.count > 1 ? parts[1] : "Forge"
                let relativeArgs = "libraries/net/minecraftforge/forge/\(versionName)/unix_args.txt"

                profiles.append(ServerLaunchProfile(
                    id: "forge:\(versionName)",
                    displayName: "Forge \(minecraftVersion)",
                    minecraftVersion: minecraftVersion,
                    loader: "Forge \(forgeVersion)",
                    arguments: ["@user_jvm_args.txt", "@\(relativeArgs)", "nogui"],
                    detail: relativeArgs
                ))
            }
        }

        for jarURL in discoverRunnableJars(in: normalizedPath) {
            let relativePath = relativeServerPath(for: jarURL, in: normalizedPath)
            let versionName = jarVersionName(for: jarURL)
            profiles.append(ServerLaunchProfile(
                id: "jar:\(relativePath)",
                displayName: "Vanilla \(versionName)",
                minecraftVersion: versionName,
                loader: "Server Jar",
                arguments: ["@user_jvm_args.txt", "-jar", relativePath, "nogui"],
                detail: relativePath
            ))
        }

        return profiles.sorted {
            if $0.loader == $1.loader { return $0.displayName < $1.displayName }
            return $0.loader < $1.loader
        }
    }

    private static func discoverRunnableJars(in serverPath: String) -> [URL] {
        let fileManager = FileManager.default
        let rootURL = URL(fileURLWithPath: serverPath)
        guard let enumerator = fileManager.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var jars: [URL] = []
        for case let jarURL as URL in enumerator {
            guard jarURL.pathExtension == "jar" else { continue }
            let relativePath = relativeServerPath(for: jarURL, in: serverPath)
            guard !relativePath.hasPrefix("libraries/") && !relativePath.contains("/libraries/") else { continue }
            guard !jarURL.lastPathComponent.lowercased().contains("installer") else { continue }
            guard isLikelyRunnableServerJar(jarURL.lastPathComponent) else { continue }
            jars.append(jarURL)
        }
        return jars
    }

    private static func isLikelyRunnableServerJar(_ fileName: String) -> Bool {
        let lowercasedName = fileName.lowercased()
        return lowercasedName == "server.jar"
            || lowercasedName.hasPrefix("server-")
            || lowercasedName.hasPrefix("paper-")
            || lowercasedName.hasPrefix("spigot-")
            || lowercasedName.hasPrefix("fabric-server")
            || lowercasedName.hasPrefix("purpur-")
    }

    private static func relativeServerPath(for url: URL, in serverPath: String) -> String {
        let rootPath = URL(fileURLWithPath: serverPath).standardizedFileURL.path
        let fullPath = url.standardizedFileURL.path
        if fullPath.hasPrefix(rootPath + "/") {
            return String(fullPath.dropFirst(rootPath.count + 1))
        }
        return url.lastPathComponent
    }

    private static func jarVersionName(for url: URL) -> String {
        let parentName = url.deletingLastPathComponent().lastPathComponent
        let fileName = url.deletingPathExtension().lastPathComponent

        if parentName.range(of: #"^\d+\.\d+(\.\d+)?$"#, options: .regularExpression) != nil {
            return parentName
        }
        if let range = fileName.range(of: #"\d+\.\d+(\.\d+)?"#, options: .regularExpression) {
            return String(fileName[range])
        }
        return "Custom"
    }

    func property(_ key: String, fallback: String = "") -> String {
        properties[key] ?? fallback
    }

    func setProperty(_ key: String, value: String) {
        properties[key] = value
    }

    func boolProperty(_ key: String, fallback: Bool = false) -> Bool {
        (properties[key] ?? (fallback ? "true" : "false")) == "true"
    }

    func setBoolProperty(_ key: String, value: Bool) {
        properties[key] = value ? "true" : "false"
    }

    func intProperty(_ key: String, fallback: Int) -> Int {
        Int(properties[key] ?? "") ?? fallback
    }

    func setIntProperty(_ key: String, value: Int) {
        properties[key] = "\(value)"
    }

    var motd: String { property("motd", fallback: "Minecraft Server") }
    var serverPort: String {
        if isMinecraftServer {
            return property("server-port", fallback: "25565")
        }
        return config.customServerPort.isEmpty ? config.gameKind.defaultPort : config.customServerPort
    }
    var maxPlayers: String { property("max-players", fallback: "20") }
    var localAddress: String { "127.0.0.1:\(serverPort)" }

    var motdText: String {
        stripMOTDFormatting(motd).replacingOccurrences(of: "\\n", with: "\n")
    }

    var formattedMOTD: String {
        normalizedMOTDFormatting(motd).replacingOccurrences(of: "\\n", with: "\n")
    }

    var motdColorCode: String {
        extractMOTDColorCode(from: motd) ?? "f"
    }

    func setMOTD(text: String, colorCode: String) {
        let escapedText = text
            .replacingOccurrences(of: "\n", with: "\\n")
            .trimmingCharacters(in: .newlines)
        setProperty("motd", value: "\\u00A7\(colorCode)\(escapedText)")
    }

    func setFormattedMOTD(_ formattedValue: String) {
        let escapedValue = formattedValue
            .replacingOccurrences(of: "\u{00A7}", with: "\\u00A7")
            .replacingOccurrences(of: "\n", with: "\\n")
            .trimmingCharacters(in: .newlines)
        setProperty("motd", value: escapedValue)
    }

    private func extractMOTDColorCode(from value: String) -> String? {
        let normalizedValue = normalizedMOTDFormatting(value)
        let sectionSign = "\u{00A7}"
        let colorCodes = Set("0123456789abcdef")
        let characters = Array(normalizedValue.lowercased())

        for index in characters.indices.dropLast() {
            if String(characters[index]) == sectionSign && colorCodes.contains(characters[index + 1]) {
                return String(characters[index + 1])
            }
        }
        return nil
    }

    private func stripMOTDFormatting(_ value: String) -> String {
        let normalizedValue = normalizedMOTDFormatting(value)
        let sectionSign = Character("\u{00A7}")
        let allowedCodes = Set("0123456789abcdefklmnor")
        var stripped = ""
        var iterator = normalizedValue.makeIterator()

        while let character = iterator.next() {
            if character == sectionSign, let code = iterator.next() {
                if allowedCodes.contains(Character(String(code).lowercased())) {
                    continue
                }
                stripped.append(character)
                stripped.append(code)
            } else {
                stripped.append(character)
            }
        }

        return stripped
    }

    private func normalizedMOTDFormatting(_ value: String) -> String {
        value.replacingOccurrences(of: "\\u00A7", with: "\u{00A7}", options: .caseInsensitive)
    }

    func copyToClipboard(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }

    func openServerFolder() {
        NSWorkspace.shared.open(URL(fileURLWithPath: serverPath))
    }

    static func freePort(_ port: String) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", "lsof -ti tcp:\(port) 2>/dev/null | xargs kill -9 2>/dev/null; true"]
        try? task.run()
        task.waitUntilExit()
    }

    static func killOrphanedJavaProcesses() {
        DispatchQueue.global(qos: .utility).async {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
            task.arguments = ["-f", "(minecraft_server|forge|paper|fabric).*jar"]
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = nil
            try? task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let pids = String(data: data, encoding: .utf8)?
                .split(whereSeparator: \.isNewline)
                .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) } ?? []
            for pid in pids where pid > 0 && pid != ProcessInfo.processInfo.processIdentifier {
                let killTask = Process()
                killTask.executableURL = URL(fileURLWithPath: "/bin/kill")
                killTask.arguments = ["-9", "\(pid)"]
                try? killTask.run()
                killTask.waitUntilExit()
            }
        }
    }

    func forceKillAllProcesses() {
        if let p = process {
            if let outPipe = p.standardOutput as? Pipe {
                outPipe.fileHandleForReading.readabilityHandler = nil
            }
            p.terminate()
        }
        process = nil
        if let t = tunnelProcess {
            if let outPipe = t.standardOutput as? Pipe {
                outPipe.fileHandleForReading.readabilityHandler = nil
            }
            t.terminate()
        }
        tunnelProcess = nil
        isRunning = false
        stopResourceMonitor()
        stopPlayit()
        stopAutoBackupTimer()
        stopAutoScaling()
        flushLogBuffer()
        stopLogFlushTimer()
        Self.killOrphanedJavaProcesses()
        logOutput += "[Kill] All server processes terminated.\n"
    }

    private func startLogFlushTimer() {
        stopLogFlushTimer()
        logBuffer = ""
        logFlushTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            self?.flushLogBuffer()
        }
    }

    private func stopLogFlushTimer() {
        logFlushTimer?.invalidate()
        logFlushTimer = nil
    }

    private func flushLogBuffer() {
        guard !logBuffer.isEmpty else { return }
        logOutput += logBuffer
        logBuffer = ""
    }

    func timestampedString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return "[\(formatter.string(from: Date()))] "
    }

    func openFile(_ path: String) {
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    private func loadPlayers() {
        ops = loadPlayerFile(opsFile)
        whitelist = loadPlayerFile(whitelistFile)
    }

    private func loadPlayerFile(_ path: String) -> [MinecraftPlayerRecord] {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return [] }
        return (try? JSONDecoder().decode([MinecraftPlayerRecord].self, from: data)) ?? []
    }

    func start() {
        guard !isRunning else { return }
        Self.requestNotificationPermission()

        if !isMinecraftServer {
            startGenericServer()
            return
        }

        guard let launchProfile = selectedLaunchProfile else {
            logOutput = "[Error] No installed server version was found in \(serverPath).\n"
            return
        }
        logOutput = ""
        networkLog = ""
        guard let javaExecutable = javaExecutableURL(for: launchProfile) else {
            let requiredVersion = requiredJavaMajorVersion(for: launchProfile)
            logOutput = "[Error] \(launchProfile.displayName) requires Java \(requiredVersion)+, but no matching Java was found.\n"
            return
        }
        stopPlayit()
        tunnelURL = "Starting..."
        saveRamSettings()
        logOutput += "[Info] Starting server...\n"

        try? FileManager.default.removeItem(atPath: "\(serverPath)/world/session.lock")

        ServerInstance.freePortAsync(serverPort) { [weak self] in
            guard let self = self else { return }
            self.launchServer(java: javaExecutable, launchProfile: launchProfile)
        }
    }

    private func launchServer(java javaExecutable: URL, launchProfile: ServerLaunchProfile) {
        guard !isRunning else { return }
        let process = Process()
        process.executableURL = javaExecutable
        process.arguments = launchProfile.arguments
        process.currentDirectoryURL = URL(fileURLWithPath: serverPath)

        let outPipe = Pipe()
        self.inputPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = outPipe
        process.standardInput = self.inputPipe

        outPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if let text = String(data: data, encoding: .utf8), !text.isEmpty {
                DispatchQueue.main.async {
                    self?.logBuffer += text
                    if text.contains("Done") && text.contains("For help") { self?.startPlayit() }
                }
            }
        }

        startLogFlushTimer()

        let weakSelf = self
        process.terminationHandler = { _ in
            outPipe.fileHandleForReading.readabilityHandler = nil
            DispatchQueue.main.async {
                weakSelf.flushLogBuffer()
                weakSelf.stopLogFlushTimer()
                weakSelf.isRunning = false
                weakSelf.stopResourceMonitor()
                weakSelf.stopPlayit()
                weakSelf.stopAutoBackupTimer()
                weakSelf.stopAutoScaling()
                weakSelf.process = nil
                weakSelf.detectCrash()
            }
        }

        do {
            self.process = process
            try process.run()
            self.isRunning = true
            self.startTime = Date()
            self.startResourceMonitor(pid: process.processIdentifier)
            self.startAutoBackupTimer()
            self.startAutoScaling()
            Self.postNotification(title: "Server Started", body: "\(self.config.name) is now online.")
        } catch {
            outPipe.fileHandleForReading.readabilityHandler = nil
            self.stopLogFlushTimer()
            self.process = nil
            self.stopResourceMonitor()
            self.tunnelURL = "Offline"
            self.logOutput += "[Error] \(error.localizedDescription)\n"
        }
    }

    private func detectCrash() {
        guard let startTime = startTime else { return }
        let runtime = Date().timeIntervalSince(startTime)
        self.startTime = nil

        let isBindError = logOutput.contains("Address already in use") || logOutput.contains("BindException")
        if isBindError {
            logOutput += "[Port] Port \(serverPort) was in use. Retrying...\n"
            crashCount = 0
            ServerInstance.freePortAsync(serverPort) { [weak self] in
                self?.start()
            }
            return
        }

        if runtime < 15 {
            crashCount += 1
            logOutput += "[Crash] Server stopped unexpectedly after \(Int(runtime))s (crash #\(crashCount))\n"
            Self.postNotification(title: "Server Crashed", body: "\(config.name) stopped after \(Int(runtime))s (crash #\(crashCount))")
        } else {
            crashCount = 0
            logOutput += "[Info] Server stopped normally after \(Int(runtime))s\n"
            Self.postNotification(title: "Server Stopped", body: "\(config.name) is now offline.")
        }

        guard autoRestart, isMinecraftServer else { return }

        if let lastAttempt = lastRestartAttempt, Date().timeIntervalSince(lastAttempt) < restartCooldown {
            logOutput += "[Crash] Skipping auto-restart (cooldown active)\n"
            return
        }

        if crashCount >= 3 {
            logOutput += "[Crash] Too many crashes (\(crashCount)). Auto-restart disabled.\n"
            autoRestart = false
            Self.postNotification(title: "Auto-Restart Disabled", body: "\(config.name) crashed \(crashCount) times.")
            return
        }

        lastRestartAttempt = Date()
        logOutput += "[Crash] Auto-restarting in 5 seconds...\n"
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            guard let self = self, self.autoRestart else { return }
            self.start()
        }
    }

    private func startGenericServer() {
        logOutput = ""
        networkLog = ""

        let executablePath = ServerInstance.normalizedServerPath(config.customExecutablePath)
        guard !executablePath.isEmpty else {
            logOutput = "[Error] Choose a server executable in Options before starting \(config.gameKind.displayName).\n"
            return
        }
        guard FileManager.default.isExecutableFile(atPath: executablePath) else {
            logOutput = "[Error] The server executable is missing or not executable: \(executablePath)\n"
            return
        }

        stopPlayit()
        tunnelURL = "Offline"

        ServerInstance.freePortAsync(config.customServerPort.isEmpty ? "25565" : config.customServerPort) { [weak self] in
            guard let self = self else { return }
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executablePath)
            process.arguments = self.parseLaunchArguments(self.config.customLaunchArguments)
            process.currentDirectoryURL = URL(fileURLWithPath: self.serverPath)

            let outPipe = Pipe()
            self.inputPipe = Pipe()
            process.standardOutput = outPipe
            process.standardError = outPipe
            process.standardInput = self.inputPipe

            outPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                if let text = String(data: data, encoding: .utf8), !text.isEmpty {
                    DispatchQueue.main.async {
                        self?.logBuffer += text
                    }
                }
            }

            self.startLogFlushTimer()

            let weakSelf = self
            process.terminationHandler = { _ in
                outPipe.fileHandleForReading.readabilityHandler = nil
                DispatchQueue.main.async {
                    weakSelf.flushLogBuffer()
                    weakSelf.stopLogFlushTimer()
                    weakSelf.isRunning = false
                    weakSelf.stopResourceMonitor()
                    weakSelf.stopAutoBackupTimer()
                    weakSelf.stopAutoScaling()
                    weakSelf.process = nil
                }
            }

            do {
                self.process = process
                self.logOutput += "[Info] Starting \(self.config.gameKind.displayName): \(executablePath)\n"
                try process.run()
                self.isRunning = true
                self.startTime = Date()
                self.startResourceMonitor(pid: process.processIdentifier)
                self.startAutoBackupTimer()
                self.startAutoScaling()
                Self.postNotification(title: "Server Started", body: "\(self.config.name) is now online.")
            } catch {
                self.process = nil
                self.stopResourceMonitor()
                self.logOutput += "[Error] \(error.localizedDescription)\n"
            }
        }
    }

    private func parseLaunchArguments(_ input: String) -> [String] {
        var arguments: [String] = []
        var current = ""
        var quote: Character?
        var isEscaping = false

        for character in input {
            if isEscaping {
                current.append(character)
                isEscaping = false
                continue
            }

            if character == "\\" {
                isEscaping = true
                continue
            }

            if character == "\"" || character == "'" {
                if quote == character {
                    quote = nil
                } else if quote == nil {
                    quote = character
                } else {
                    current.append(character)
                }
                continue
            }

            if character.isWhitespace && quote == nil {
                if !current.isEmpty {
                    arguments.append(current)
                    current = ""
                }
            } else {
                current.append(character)
            }
        }

        if !current.isEmpty {
            arguments.append(current)
        }

        return arguments
    }

    private func javaExecutableURL(for launchProfile: ServerLaunchProfile) -> URL? {
        let requiredMajor = requiredJavaMajorVersion(for: launchProfile)
        guard let candidate = ServerInstance.javaExecutablePath(requiredMajor: requiredMajor) else {
            return nil
        }
        let major = ServerInstance.javaMajorVersion(at: candidate) ?? requiredMajor
        logOutput += "[Info] Using Java \(major): \(candidate)\n"
        return URL(fileURLWithPath: candidate)
    }

    static func freePortAsync(_ port: String, completion: @escaping () -> Void = {}) {
        DispatchQueue.global(qos: .utility).async {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/bin/sh")
            task.arguments = ["-c", "lsof -ti tcp:\(port) 2>/dev/null | xargs kill -9 2>/dev/null; true"]
            try? task.run()
            task.waitUntilExit()
            DispatchQueue.main.async(execute: completion)
        }
    }

    private func requiredJavaMajorVersion(for launchProfile: ServerLaunchProfile) -> Int {
        ServerInstance.javaMajorRequirement(forMinecraftVersion: launchProfile.minecraftVersion)
    }

    static func javaMajorRequirement(forMinecraftVersion version: String) -> Int {
        let parts = version.split(separator: ".").compactMap { Int($0) }
        guard parts.count >= 2 else { return 17 }

        let major = parts[0]
        let minor = parts[1]
        let patch = parts.count > 2 ? parts[2] : 0

        if major > 1 || (major == 1 && (minor > 20 || (minor == 20 && patch >= 5))) {
            return 21
        }
        if major == 1 && minor >= 18 {
            return 17
        }
        if major == 1 && minor == 17 {
            return 16
        }
        return 8
    }

    static func javaExecutablePath(requiredMajor: Int) -> String? {
        for candidate in javaExecutableCandidates(requiredMajor: requiredMajor) {
            guard FileManager.default.isExecutableFile(atPath: candidate) else { continue }
            if let major = javaMajorVersion(at: candidate), major >= requiredMajor {
                return candidate
            }
        }
        return nil
    }

    private static func javaExecutableCandidates(requiredMajor: Int) -> [String] {
        var candidates: [String] = []
        if requiredMajor >= 21 {
            candidates += [
                "/opt/homebrew/opt/openjdk/bin/java",
                "/opt/homebrew/opt/openjdk@25/bin/java",
                "/opt/homebrew/opt/openjdk@24/bin/java",
                "/opt/homebrew/opt/openjdk@23/bin/java",
                "/opt/homebrew/opt/openjdk@22/bin/java",
                "/opt/homebrew/opt/openjdk@21/bin/java"
            ]
        }

        candidates += [
            "/opt/homebrew/opt/openjdk@17/bin/java",
            "/opt/homebrew/opt/openjdk/bin/java",
            NSHomeDirectory() + "/Library/Application Support/minecraft/runtime/java-runtime-gamma/mac-os-arm64/java-runtime-gamma/jre.bundle/Contents/Home/bin/java",
            "/usr/bin/java"
        ]

        var uniqueCandidates: [String] = []
        for candidate in candidates where !uniqueCandidates.contains(candidate) {
            uniqueCandidates.append(candidate)
        }
        return uniqueCandidates
    }

    static func javaMajorVersion(at path: String) -> Int? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: path)
        task.arguments = ["-version"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            return javaMajorVersion(from: output)
        } catch {
            return nil
        }
    }

    private static func javaMajorVersion(from output: String) -> Int? {
        guard let range = output.range(of: #"version "([^"]+)""#, options: .regularExpression) else {
            return nil
        }

        let versionText = String(output[range])
            .replacingOccurrences(of: "version \"", with: "")
            .replacingOccurrences(of: "\"", with: "")
        let components = versionText.split(separator: ".").compactMap { Int($0) }

        if components.first == 1, components.count > 1 {
            return components[1]
        }
        return components.first
    }

    private func startResourceMonitor(pid: Int32) {
        stopResourceMonitor()
        pollResourceUsage(pid: pid)
        usageTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.pollResourceUsage(pid: pid)
        }
    }

    private func stopResourceMonitor() {
        usageTimer?.invalidate()
        usageTimer = nil
        cpuUsagePercent = 0
        ramUsageMB = 0
    }

    private func pollResourceUsage(pid: Int32) {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/bin/ps")
            task.arguments = ["-o", "%cpu=", "-o", "rss=", "-p", "\(pid)"]

            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = Pipe()

            do {
                try task.run()
                task.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                let parts = output.split(whereSeparator: { $0.isWhitespace })

                guard parts.count >= 2,
                      let cpu = Double(parts[0]),
                      let rssKB = Double(parts[1]) else { return }

                DispatchQueue.main.async {
                    self?.cpuUsagePercent = cpu
                    self?.ramUsageMB = rssKB / 1024
                }
            } catch {
                DispatchQueue.main.async {
                    self?.cpuUsagePercent = 0
                    self?.ramUsageMB = 0
                }
            }
        }
    }

    func startPlayit() {
        guard tunnelProcess?.isRunning != true else { return }
        networkLog += "[Network] Starting your Playit agent...\n"
        networkLog += "[Network] Minecraft-adresse: \(publicJoinAddress)\n"
        networkLog += "[Network] Playit endpoint: \(playitTargetAddress)\n"
        tunnelURL = publicJoinAddress

        let tProc = Process()
        tProc.executableURL = URL(fileURLWithPath: ServerInstance.playitBin)
        tProc.arguments = ["-s"]
        
        let pipe = Pipe()
        tProc.standardOutput = pipe
        tProc.standardError = pipe
        
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if let line = String(data: data, encoding: .utf8), !line.isEmpty {
                DispatchQueue.main.async {
                    self?.networkLog += line
                    if line.contains(".at.ply.gg") || line.contains(".playit.gg") {
                        if let url = self?.extractURL(from: line) {
                            self?.tunnelURL = url
                        }
                    }
                }
            }
        }

        tProc.terminationHandler = { [weak self] process in
            pipe.fileHandleForReading.readabilityHandler = nil
            DispatchQueue.main.async {
                self?.networkLog += "[Network] Playit stopped with code \(process.terminationStatus)\n"
                self?.tunnelProcess = nil
                if self?.isRunning == true {
                    self?.tunnelURL = "Playit offline"
                }
            }
        }

        self.tunnelProcess = tProc
        do {
            try tProc.run()
        } catch {
            self.tunnelProcess = nil
            tunnelURL = "Playit fejl"
            networkLog += "[Network] Kunne ikke starte Playit: \(error.localizedDescription)\n"
        }
    }

    private func extractURL(from text: String) -> String? {
        let pattern = #"[a-z0-9.-]+\.(playit\.gg|at\.ply\.gg)(:[0-9]+)?"#
        if let range = text.range(of: pattern, options: .regularExpression) {
            return String(text[range])
        }
        return nil
    }

    func stop() {
        guard isRunning else {
            stopPlayit()
            return
        }
        sendCommand("stop")
        DispatchQueue.global(qos: .default).async { [weak self] in
            Thread.sleep(forTimeInterval: 5)
            DispatchQueue.main.async {
                guard let self = self, self.isRunning else { return }
                if let p = self.process {
                    if let outPipe = p.standardOutput as? Pipe {
                        outPipe.fileHandleForReading.readabilityHandler = nil
                    }
                    p.terminate()
                }
                self.process = nil
                self.isRunning = false
                self.stopPlayit()
                self.stopResourceMonitor()
                self.stopAutoBackupTimer()
                self.stopAutoScaling()
            }
        }
    }

    func stopPlayit() {
        if let t = tunnelProcess {
            if let outPipe = t.standardOutput as? Pipe {
                outPipe.fileHandleForReading.readabilityHandler = nil
            }
            if t.isRunning {
                t.terminate()
            }
        }
        tunnelProcess = nil
        tunnelURL = "Offline"
    }

    func sendCommand(_ command: String) {
        let cmd = command + "\n"
        try? inputPipe.fileHandleForWriting.write(contentsOf: cmd.data(using: .utf8)!)
    }

    private func saveRamSettings() {
        let boundedThreads = min(max(cpuThreads, 1), ServerInstance.maxCPUThreads)
        let concThreads = max(1, boundedThreads / 2)
        let ramContent = """
        -Xms1G
        -Xmx\(ramGB)G
        -XX:ActiveProcessorCount=\(boundedThreads)
        -XX:+UseG1GC
        -XX:ParallelGCThreads=\(boundedThreads)
        -XX:ConcGCThreads=\(concThreads)

        """
        try? ramContent.write(toFile: jvmArgsFile, atomically: true, encoding: .utf8)
    }

    func saveSettings() {
        saveRamSettings()
        var propsContent = "# Updated by Minecraft Controller\n"
        for key in properties.keys.sorted() {
            if let value = properties[key] {
                propsContent += "\(key)=\(value)\n"
            }
        }
        do {
            try propsContent.write(toFile: propertiesFile, atomically: true, encoding: .utf8)
            lastSavedMessage = "Settings saved. Restart the server for changed options to apply."
        } catch {
            lastSavedMessage = "Could not save settings: \(error.localizedDescription)"
        }
        loadAllSettings()
    }
    
    static var playitBin: String {
        let candidates = [
            "/opt/homebrew/bin/playit",
            "/usr/local/bin/playit",
            "/usr/bin/playit",
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) } ?? "/opt/homebrew/bin/playit"
    }

    static var maxCPUThreads: Int {
        max(1, ProcessInfo.processInfo.processorCount)
    }

    static var maxSystemRamGB: Int {
        max(1, Int(ProcessInfo.processInfo.physicalMemory / 1_073_741_824))
    }

    static func normalizedServerPath(_ path: String) -> String {
        (path as NSString).expandingTildeInPath.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Server Updates
    struct ServerUpdateCheck: Identifiable {
        let id: String
        let currentVersion: String
        let latestVersion: String
        let isUpToDate: Bool
        let downloadURL: String?
    }

    func checkForUpdates() async -> ServerUpdateCheck? {
        guard isMinecraftServer, let profile = selectedLaunchProfile else { return nil }
        let currentVer = profile.minecraftVersion

        if profile.loader.contains("Forge") {
            do {
                let allForge = try await ServerManager.fetchForgeVersions(limit: 50)
                let matching = allForge.filter { $0.minecraftVersion == currentVer }
                if let latestForge = matching.first {
                    let isUpToDate = latestForge.id == config.selectedLaunchProfileID
                    return ServerUpdateCheck(
                        id: "forge:\(currentVer)",
                        currentVersion: profile.displayName,
                        latestVersion: latestForge.displayName,
                        isUpToDate: isUpToDate,
                        downloadURL: isUpToDate ? nil : latestForge.installerURL
                    )
                }
            } catch {}
            return nil
        }

        do {
            let allVanilla = try await ServerManager.fetchVanillaVersions(limit: 30)
            if let latestVanilla = allVanilla.first {
                let isUpToDate = latestVanilla.id == currentVer
                return ServerUpdateCheck(
                    id: "vanilla:\(currentVer)",
                    currentVersion: currentVer,
                    latestVersion: latestVanilla.id,
                    isUpToDate: isUpToDate,
                    downloadURL: isUpToDate ? nil : latestVanilla.url
                )
            }
        } catch {}
        return nil
    }

    func performUpdate(_ check: ServerUpdateCheck) async throws {
        guard !isRunning else { throw ServerSetupError.invalidPath }
        guard let url = check.downloadURL, let downloadURL = URL(string: url) else { return }

        if check.id.hasPrefix("forge:") {
            let data = try await ServerManager.fetchData(from: downloadURL)
            let installerName = "forge-update-installer.jar"
            let installerPath = "\(serverPath)/\(installerName)"
            try data.write(to: URL(fileURLWithPath: installerPath))
            try await ServerManager.runForgeInstaller(
                version: ForgeVersionSummary(id: "", minecraftVersion: "", forgeVersion: "", installerURL: ""),
                installerPath: installerPath,
                serverPath: serverPath
            )
            try? FileManager.default.removeItem(atPath: installerPath)
        } else {
            let data = try await ServerManager.fetchData(from: downloadURL)
            let versionData = try JSONDecoder().decode(MinecraftVersionDetails.self, from: data)
            guard let serverURL = versionData.downloads.server?.url,
                  let jarURL = URL(string: serverURL) else {
                throw ServerSetupError.missingServerDownload
            }
            let jarData = try await ServerManager.fetchData(from: jarURL)
            let newJarName = "server-\(check.latestVersion).jar"
            try jarData.write(to: URL(fileURLWithPath: "\(serverPath)/\(newJarName)"), options: .atomic)
        }

        refreshLaunchProfiles()
    }

    // MARK: - Mods
    struct ModEntry: Identifiable {
        let id: String
        let fileName: String
        let isEnabled: Bool
        let fileSize: Int64
        let lastModified: Date

        var formattedSize: String {
            ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
        }
    }

    func listMods() -> [ModEntry] {
        let modsDir = URL(fileURLWithPath: "\(serverPath)/mods")
        guard let files = try? FileManager.default.contentsOfDirectory(at: modsDir, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey]) else {
            return []
        }

        return files.filter { $0.pathExtension == "jar" || $0.pathExtension == "disabled" }
            .compactMap { url -> ModEntry? in
                let fileName = url.lastPathComponent
                let isEnabled = url.pathExtension == "jar"
                let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
                let fileSize = attrs?[.size] as? Int64 ?? 0
                let lastModified = attrs?[.modificationDate] as? Date ?? Date()
                return ModEntry(id: fileName, fileName: fileName, isEnabled: isEnabled, fileSize: fileSize, lastModified: lastModified)
            }
            .sorted { $0.fileName < $1.fileName }
    }

    func toggleMod(_ entry: ModEntry) {
        let modsDir = URL(fileURLWithPath: "\(serverPath)/mods")
        let source = modsDir.appendingPathComponent(entry.fileName)
        let newName = entry.isEnabled ? "\(entry.fileName).disabled" : String(entry.fileName.dropLast(9))
        let dest = modsDir.appendingPathComponent(newName)
        try? FileManager.default.moveItem(at: source, to: dest)
    }

    func deleteMod(_ entry: ModEntry) {
        let modsDir = URL(fileURLWithPath: "\(serverPath)/mods")
        let target = modsDir.appendingPathComponent(entry.fileName)
        try? FileManager.default.removeItem(at: target)
    }

    // MARK: - Auto-scaling
    private var scaleTimer: Timer?
    private var ramSamples: [Double] = []

    func startAutoScaling() {
        stopAutoScaling()
        guard autoScaleEnabled, isRunning else { return }
        scaleTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.evaluateScaling()
        }
    }

    func stopAutoScaling() {
        scaleTimer?.invalidate()
        scaleTimer = nil
        ramSamples = []
    }

    private func evaluateScaling() {
        ramSamples.append(ramUsageMB)
        if ramSamples.count > 10 { ramSamples.removeFirst() }
        guard ramSamples.count >= 3 else { return }

        let avgRAM = ramSamples.reduce(0, +) / Double(ramSamples.count)
        let maxRAM = Double(ramGB * 1024)
        let usagePct = avgRAM / maxRAM

        if usagePct > 0.85, ramGB < ServerInstance.maxSystemRamGB {
            ramGB = min(ramGB + 1, ServerInstance.maxSystemRamGB)
            saveRamSettings()
            logOutput += "[Auto-scale] RAM increased to \(ramGB) GB (usage was \(Int(usagePct * 100))%)\n"
            ramSamples = []
        } else if usagePct < 0.30, ramGB > 2 {
            ramGB = max(ramGB - 1, 2)
            saveRamSettings()
            logOutput += "[Auto-scale] RAM decreased to \(ramGB) GB (usage was \(Int(usagePct * 100))%)\n"
            ramSamples = []
        }
    }

    // MARK: - Backups
    func loadBackups() {
        guard FileManager.default.fileExists(atPath: backupsFile),
              let data = try? Data(contentsOf: URL(fileURLWithPath: backupsFile)),
              let decoded = try? JSONDecoder().decode([BackupRecord].self, from: data) else {
            backups = []
            return
        }
        backups = decoded.sorted { $0.date > $1.date }
    }

    private func saveBackups() {
        try? FileManager.default.createDirectory(atPath: backupsDir, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(backups) {
            try? data.write(to: URL(fileURLWithPath: backupsFile))
        }
    }

    func createBackup() {
        let worldName = property("level-name", fallback: "world")
        let worldPath = "\(serverPath)/\(worldName)"
        guard FileManager.default.fileExists(atPath: worldPath) else {
            DispatchQueue.main.async { [weak self] in
                self?.logOutput += "[Backup] World folder not found: \(worldPath)\n"
            }
            return
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let dateStr = formatter.string(from: Date())
        let zipName = "\(worldName)-\(dateStr).zip"
        let zipPath = "\(backupsDir)/\(zipName)"

        try? FileManager.default.createDirectory(atPath: backupsDir, withIntermediateDirectories: true)

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        task.arguments = ["-r", "--symlinks", zipPath, worldName]
        task.currentDirectoryURL = URL(fileURLWithPath: serverPath)

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.logOutput += "[Backup] Failed to create backup: \(error.localizedDescription)\n"
            }
            return
        }

        guard task.terminationStatus == 0 else {
            DispatchQueue.main.async { [weak self] in
                self?.logOutput += "[Backup] zip command failed with status \(task.terminationStatus)\n"
            }
            return
        }

        let attrs = try? FileManager.default.attributesOfItem(atPath: zipPath)
        let fileSize = attrs?[.size] as? Int64 ?? 0

        let record = BackupRecord(id: UUID(), date: Date(), fileName: zipName, fileSize: fileSize, worldName: worldName)

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.backups.insert(record, at: 0)

            while self.backups.count > self.maxBackups {
                let removed = self.backups.removeLast()
                try? FileManager.default.removeItem(atPath: "\(self.backupsDir)/\(removed.fileName)")
            }

            self.saveBackups()
            self.logOutput += "[Backup] Created backup: \(zipName) (\(record.formattedSize))\n"
            Self.postNotification(title: "Backup Complete", body: "\(self.config.name): \(zipName) (\(record.formattedSize))")
        }
    }

    func restoreBackup(_ record: BackupRecord) {
        guard !isRunning else {
            logOutput += "[Backup] Stop the server before restoring a backup.\n"
            return
        }

        let worldName = record.worldName
        let worldPath = "\(serverPath)/\(worldName)"
        let zipPath = "\(backupsDir)/\(record.fileName)"

        guard FileManager.default.fileExists(atPath: zipPath) else {
            logOutput += "[Backup] Backup file not found: \(record.fileName)\n"
            return
        }

        try? FileManager.default.removeItem(atPath: worldPath)
        try? FileManager.default.removeItem(atPath: "\(worldPath)_nether")
        try? FileManager.default.removeItem(atPath: "\(worldPath)_the_end")

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        task.arguments = ["-o", zipPath, "-d", serverPath]
        task.currentDirectoryURL = URL(fileURLWithPath: serverPath)

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            logOutput += "[Backup] Failed to restore backup: \(error.localizedDescription)\n"
            return
        }

        guard task.terminationStatus == 0 else {
            logOutput += "[Backup] unzip command failed with status \(task.terminationStatus)\n"
            return
        }

        logOutput += "[Backup] Restored world from backup: \(record.fileName) (\(record.formattedDate))\n"
        loadAllSettings()
        Self.postNotification(title: "Backup Restored", body: "\(config.name): \(record.fileName)")
    }

    func deleteBackup(_ record: BackupRecord) {
        let zipPath = "\(backupsDir)/\(record.fileName)"
        try? FileManager.default.removeItem(atPath: zipPath)
        backups.removeAll { $0.id == record.id }
        saveBackups()
    }

    func startAutoBackupTimer() {
        stopAutoBackupTimer()
        guard backupEnabled, isRunning else { return }
        let interval = max(backupIntervalHours, 0.5) * 3600
        backupTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.createBackup()
        }
    }

    func stopAutoBackupTimer() {
        backupTimer?.invalidate()
        backupTimer = nil
    }

    // MARK: - Notifications
    static func postNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    private static var didRequestNotificationPermission = false
    static func requestNotificationPermission() {
        guard !didRequestNotificationPermission else { return }
        didRequestNotificationPermission = true
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
}

class ServerManager: ObservableObject {
    @Published var instances: [ServerInstance] = []
    
    func saveConfigs() {
        let configs = instances.map { $0.config }
        if let encoded = try? JSONEncoder().encode(configs) {
            UserDefaults.standard.set(encoded, forKey: "servers")
        }
    }
    
    @Published var selectedInstanceID: UUID? {
        didSet {
            if let selectedInstanceID = selectedInstanceID {
                UserDefaults.standard.set(selectedInstanceID.uuidString, forKey: "selectedServerID")
            }
        }
    }

    var selectedInstance: ServerInstance? {
        instances.first { $0.id == selectedInstanceID }
    }

    init() {
        var loadedConfigs: [ServerConfiguration] = []
        if let savedServersData = UserDefaults.standard.data(forKey: "servers"),
           let decodedServers = try? JSONDecoder().decode([ServerConfiguration].self, from: savedServersData) {
            loadedConfigs = decodedServers
        } else {
            var defaultConfig = ServerConfiguration(name: "Default Server", serverPath: NSHomeDirectory() + "/minecraft-server")
            defaultConfig.selectedLaunchProfileID = UserDefaults.standard.string(forKey: "selectedLaunchProfileID") ?? ""
            loadedConfigs = [defaultConfig]
        }

        self.instances = loadedConfigs.map { config in
            let instance = ServerInstance(config: config)
            instance.onConfigChanged = { [weak self] in self?.saveConfigs() }
            return instance
        }

        if let savedSelectedServerID = UserDefaults.standard.string(forKey: "selectedServerID"),
           let uuid = UUID(uuidString: savedSelectedServerID),
           self.instances.contains(where: { $0.id == uuid }) {
            self.selectedInstanceID = uuid
        } else {
            self.selectedInstanceID = self.instances.first?.id
        }
    }
    
    func addServer(
        name: String,
        path: String,
        gameKind: GameServerKind = .minecraft,
        selectedLaunchProfileID: String = "",
        acceptsEULA: Bool = false,
        customExecutablePath: String = "",
        customLaunchArguments: String = "",
        customServerPort: String = ""
    ) throws {
        let normalizedPath = ServerInstance.normalizedServerPath(path)
        guard !normalizedPath.isEmpty else { throw ServerSetupError.invalidPath }

        if gameKind == .minecraft {
            try Self.prepareMinecraftServerFolder(path: normalizedPath, name: name, acceptsEULA: acceptsEULA, defaultPort: nextAvailablePort())
        } else {
            try Self.prepareGenericServerFolder(path: normalizedPath)
        }

        var config = ServerConfiguration(name: name, serverPath: normalizedPath)
        config.gameKind = gameKind
        config.selectedLaunchProfileID = selectedLaunchProfileID
        config.customExecutablePath = ServerInstance.normalizedServerPath(customExecutablePath)
        config.customLaunchArguments = customLaunchArguments
        config.customServerPort = customServerPort.isEmpty ? gameKind.defaultPort : customServerPort
        let instance = ServerInstance(config: config)
        instance.onConfigChanged = { [weak self] in self?.saveConfigs() }
        instances.append(instance)
        selectedInstanceID = instance.id
        saveConfigs()
    }

    @MainActor
    func createVanillaServer(name: String, path: String, version: MinecraftVersionSummary, acceptsEULA: Bool) async throws {
        let normalizedPath = ServerInstance.normalizedServerPath(path)
        guard !normalizedPath.isEmpty else { throw ServerSetupError.invalidPath }

        try Self.prepareMinecraftServerFolder(path: normalizedPath, name: name, acceptsEULA: acceptsEULA, defaultPort: nextAvailablePort())
        let jarName = try await Self.downloadVanillaServerJar(version: version, to: normalizedPath)
        try addServer(name: name, path: normalizedPath, selectedLaunchProfileID: "jar:\(jarName)", acceptsEULA: acceptsEULA)
    }

    @MainActor
    func createPaperServer(name: String, path: String, version: PaperVersionSummary, acceptsEULA: Bool) async throws {
        let normalizedPath = ServerInstance.normalizedServerPath(path)
        guard !normalizedPath.isEmpty else { throw ServerSetupError.invalidPath }

        try Self.prepareMinecraftServerFolder(path: normalizedPath, name: name, acceptsEULA: acceptsEULA, defaultPort: nextAvailablePort())
        guard let jarURL = URL(string: version.downloadURL) else { throw ServerSetupError.badServerResponse }
        let jarData = try await Self.fetchData(from: jarURL)
        let jarName = "paper-\(version.minecraftVersion).jar"
        try jarData.write(to: URL(fileURLWithPath: "\(normalizedPath)/\(jarName)"), options: .atomic)
        try addServer(name: name, path: normalizedPath, selectedLaunchProfileID: "jar:\(jarName)", acceptsEULA: acceptsEULA)
    }

    @MainActor
    func createForgeServer(name: String, path: String, version: ForgeVersionSummary, acceptsEULA: Bool) async throws {
        let normalizedPath = ServerInstance.normalizedServerPath(path)
        guard !normalizedPath.isEmpty else { throw ServerSetupError.invalidPath }

        try Self.prepareMinecraftServerFolder(path: normalizedPath, name: name, acceptsEULA: acceptsEULA, defaultPort: nextAvailablePort())
        let installerPath = try await Self.downloadForgeInstaller(version: version, to: normalizedPath)
        try await Self.runForgeInstaller(version: version, installerPath: installerPath, serverPath: normalizedPath)
        try? FileManager.default.removeItem(atPath: installerPath)

        let profileID = "forge:\(version.id)"
        let profiles = ServerInstance.discoverLaunchProfiles(in: normalizedPath)
        guard profiles.contains(where: { $0.id == profileID }) else {
            throw ServerSetupError.forgeInstallFailed("Could not find the installed Forge launch profile.")
        }
        try addServer(name: name, path: normalizedPath, selectedLaunchProfileID: profileID, acceptsEULA: acceptsEULA)
    }

    @MainActor
    func createGenericGameServer(
        name: String,
        path: String,
        gameKind: GameServerKind,
        executablePath: String,
        launchArguments: String,
        serverPort: String
    ) throws {
        try addServer(
            name: name,
            path: path,
            gameKind: gameKind,
            customExecutablePath: executablePath,
            customLaunchArguments: launchArguments,
            customServerPort: serverPort
        )
    }

    @MainActor
    func createSteamCMDGameServer(
        name: String,
        path: String,
        gameKind: GameServerKind,
        launchArguments: String,
        serverPort: String,
        validate: Bool
    ) async throws {
        let normalizedPath = ServerInstance.normalizedServerPath(path)
        guard !normalizedPath.isEmpty else { throw ServerSetupError.invalidPath }
        guard let preset = gameKind.steamCMDPreset else { throw ServerSetupError.invalidVersion }

        try Self.prepareGenericServerFolder(path: normalizedPath)
        try await Self.installSteamCMDServer(preset: preset, serverPath: normalizedPath, validate: validate)

        let executablePath = URL(fileURLWithPath: normalizedPath)
            .appendingPathComponent(preset.executableRelativePath)
            .path
        try addServer(
            name: name,
            path: normalizedPath,
            gameKind: gameKind,
            customExecutablePath: executablePath,
            customLaunchArguments: launchArguments.isEmpty ? preset.launchArguments : launchArguments,
            customServerPort: serverPort.isEmpty ? preset.port : serverPort
        )
    }
    
    func removeServer(id: UUID) {
        if let index = instances.firstIndex(where: { $0.id == id }) {
            let instance = instances[index]
            instance.stop()
            instances.remove(at: index)
            if selectedInstanceID == id {
                selectedInstanceID = instances.first?.id
            }
            saveConfigs()
        }
    }

    struct PaperVersionSummary: Identifiable, Hashable {
        let id: String
        let minecraftVersion: String
        let downloadURL: String

        var displayName: String { "Paper \(minecraftVersion)" }
    }

    static func fetchPaperVersions(limit: Int = 15) async throws -> [PaperVersionSummary] {
        guard let apiURL = URL(string: "https://api.papermc.io/v2/projects/paper") else {
            throw ServerSetupError.badServerResponse
        }
        let data = try await fetchData(from: apiURL)
        struct PaperProject: Decodable { let versions: [String] }
        let project = try JSONDecoder().decode(PaperProject.self, from: data)
        let versions = project.versions.filter { $0.split(separator: ".").count >= 2 }.suffix(limit)

        var results: [PaperVersionSummary] = []
        for ver in versions {
            let buildURL = URL(string: "https://api.papermc.io/v2/projects/paper/versions/\(ver)/builds")!
            if let buildData = try? await fetchData(from: buildURL) {
                struct PaperBuild: Decodable {
                    let builds: [Build]
                    struct Build: Decodable {
                        let build: Int
                        let downloads: Downloads
                        struct Downloads: Decodable {
                            let application: Application
                            struct Application: Decodable { let name: String }
                        }
                    }
                }
                if let builds = try? JSONDecoder().decode(PaperBuild.self, from: buildData),
                   let latest = builds.builds.last {
                    let dlURL = "https://api.papermc.io/v2/projects/paper/versions/\(ver)/builds/\(latest.build)/downloads/\(latest.downloads.application.name)"
                    results.append(PaperVersionSummary(id: "paper:\(ver)", minecraftVersion: ver, downloadURL: dlURL))
                }
            }
        }
        return results
    }

    static func fetchVanillaVersions(limit: Int = 30) async throws -> [MinecraftVersionSummary] {
        guard let manifestURL = URL(string: "https://launchermeta.mojang.com/mc/game/version_manifest.json") else {
            throw ServerSetupError.invalidVersion
        }

        let data = try await fetchData(from: manifestURL)
        let manifest = try JSONDecoder().decode(MinecraftVersionManifest.self, from: data)
        return Array(manifest.versions.filter { $0.type == "release" }.prefix(limit))
    }

    static func fetchForgeVersions(limit: Int = 120) async throws -> [ForgeVersionSummary] {
        guard let metadataURL = URL(string: "https://maven.minecraftforge.net/net/minecraftforge/forge/maven-metadata.xml") else {
            throw ServerSetupError.invalidVersion
        }

        let data = try await fetchData(from: metadataURL)
        let parserDelegate = ForgeMetadataParser()
        let parser = XMLParser(data: data)
        parser.delegate = parserDelegate
        guard parser.parse() else {
            throw ServerSetupError.badServerResponse
        }

        let versions = parserDelegate.versions.reversed().compactMap { fullVersion -> ForgeVersionSummary? in
            let parts = fullVersion.split(separator: "-", maxSplits: 1).map(String.init)
            guard parts.count == 2, parts[0].hasPrefix("1.") else { return nil }
            let installerURL = "https://maven.minecraftforge.net/net/minecraftforge/forge/\(fullVersion)/forge-\(fullVersion)-installer.jar"
            return ForgeVersionSummary(
                id: fullVersion,
                minecraftVersion: parts[0],
                forgeVersion: parts[1],
                installerURL: installerURL
            )
        }

        return Array(versions.prefix(limit))
    }

    private static func downloadVanillaServerJar(version: MinecraftVersionSummary, to serverPath: String) async throws -> String {
        guard let versionURL = URL(string: version.url) else { throw ServerSetupError.invalidVersion }
        let versionData = try await fetchData(from: versionURL)
        let details = try JSONDecoder().decode(MinecraftVersionDetails.self, from: versionData)
        guard let serverURLString = details.downloads.server?.url,
              let serverURL = URL(string: serverURLString) else {
            throw ServerSetupError.missingServerDownload
        }

        let jarData = try await fetchData(from: serverURL)
        let jarName = "server-\(version.id).jar"
        let jarURL = URL(fileURLWithPath: serverPath).appendingPathComponent(jarName)
        try jarData.write(to: jarURL, options: .atomic)
        return jarName
    }

    private static func downloadForgeInstaller(version: ForgeVersionSummary, to serverPath: String) async throws -> String {
        guard let installerURL = URL(string: version.installerURL) else { throw ServerSetupError.invalidVersion }
        let installerData = try await fetchData(from: installerURL)
        let installerName = "forge-\(version.id)-installer.jar"
        let installerFileURL = URL(fileURLWithPath: serverPath).appendingPathComponent(installerName)
        try installerData.write(to: installerFileURL, options: .atomic)
        return installerFileURL.path
    }

    static func runForgeInstaller(version: ForgeVersionSummary, installerPath: String, serverPath: String) async throws {
        try await Task.detached(priority: .userInitiated) {
            let requiredJava = ServerInstance.javaMajorRequirement(forMinecraftVersion: version.minecraftVersion)
            guard let javaPath = ServerInstance.javaExecutablePath(requiredMajor: requiredJava) else {
                throw ServerSetupError.missingJava(requiredJava)
            }

            let task = Process()
            task.executableURL = URL(fileURLWithPath: javaPath)
            task.arguments = ["-jar", installerPath, "--installServer"]
            task.currentDirectoryURL = URL(fileURLWithPath: serverPath)

            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = pipe

            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            if task.terminationStatus != 0 {
                throw ServerSetupError.forgeInstallFailed(Self.shortInstallerOutput(output))
            }
        }.value
    }

    private static func installSteamCMDServer(preset: SteamCMDInstallPreset, serverPath: String, validate: Bool) async throws {
        try await Task.detached(priority: .userInitiated) {
            guard let steamCMDPath = findSteamCMDPath() else {
                throw ServerSetupError.missingSteamCMD
            }

            var arguments = [
                "+force_install_dir", serverPath,
                "+login", "anonymous"
            ]
            if let platform = preset.platform {
                arguments += ["+@sSteamCmdForcePlatformType", platform]
            }
            arguments += ["+app_update", "\(preset.appID)"]
            if validate {
                arguments.append("validate")
            }
            arguments.append("+quit")

            let task = Process()
            task.executableURL = URL(fileURLWithPath: steamCMDPath)
            task.arguments = arguments

            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = pipe

            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            if task.terminationStatus != 0 {
                throw ServerSetupError.steamCMDInstallFailed(shortInstallerOutput(output))
            }
        }.value
    }

    static func findSteamCMDPath() -> String? {
        let candidates = [
            "/opt/homebrew/bin/steamcmd",
            "/opt/homebrew/bin/steamcmd.sh",
            "/usr/local/bin/steamcmd",
            "/usr/local/bin/steamcmd.sh",
            "/Users/rasmus/steamcmd/steamcmd.sh",
            "/Users/rasmus/Steam/steamcmd.sh",
            "/Applications/SteamCMD/steamcmd.sh"
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    private static func shortInstallerOutput(_ output: String) -> String {
        let cleanedOutput = output
            .split(separator: "\n")
            .suffix(8)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanedOutput.count <= 900 {
            return cleanedOutput
        }
        return String(cleanedOutput.suffix(900))
    }

    static var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.httpAdditionalHeaders = ["User-Agent": "ServerManager/3.0 (macOS)"]
        return URLSession(configuration: config)
    }()

    static func fetchData(from url: URL) async throws -> Data {
        let (data, response) = try await urlSession.data(from: url)
        if let httpResponse = response as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            throw ServerSetupError.badServerResponse
        }
        return data
    }

    private func nextAvailablePort() -> Int {
        let usedPorts = Set(instances.compactMap { Int($0.serverPort) })
        var port = 25565
        while usedPorts.contains(port) {
            port += 1
        }
        return port
    }

    private static func prepareMinecraftServerFolder(path: String, name: String, acceptsEULA: Bool, defaultPort: Int) throws {
        let rootURL = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)

        let eulaURL = rootURL.appendingPathComponent("eula.txt")
        if acceptsEULA {
            try "eula=true\n".write(to: eulaURL, atomically: true, encoding: .utf8)
        } else {
            try writeIfMissing("eula=false\n", to: eulaURL)
        }
        try writeIfMissing(defaultJVMArgs, to: rootURL.appendingPathComponent("user_jvm_args.txt"))
        try writeIfMissing(defaultServerProperties(name: name, port: defaultPort), to: rootURL.appendingPathComponent("server.properties"))
        try writeIfMissing("[]\n", to: rootURL.appendingPathComponent("ops.json"))
        try writeIfMissing("[]\n", to: rootURL.appendingPathComponent("whitelist.json"))
        try FileManager.default.createDirectory(at: rootURL.appendingPathComponent("mods"), withIntermediateDirectories: true)
    }

    private static func prepareGenericServerFolder(path: String) throws {
        let rootURL = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
    }

    private static func writeIfMissing(_ content: String, to url: URL) throws {
        guard !FileManager.default.fileExists(atPath: url.path) else { return }
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    private static var defaultJVMArgs: String {
        """
        -Xms1G
        -Xmx4G
        -XX:ActiveProcessorCount=\(ServerInstance.maxCPUThreads)
        -XX:+UseG1GC

        """
    }

    private static func defaultServerProperties(name: String, port: Int) -> String {
        let motd = name.isEmpty ? "Minecraft Server" : name
        return """
        # Created by Minecraft Controller
        motd=\(motd)
        server-port=\(port)
        max-players=20
        online-mode=true
        gamemode=survival
        difficulty=easy
        pvp=true
        enable-command-block=false
        allow-flight=false
        allow-nether=true
        spawn-animals=true
        spawn-monsters=true
        spawn-npcs=true
        view-distance=10
        simulation-distance=10

        """
    }
}

// MARK: - Remote Server
struct RemoteServerConfig: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var host: String
    var port: Int
    var username: String
    var keyPath: String
    var serverPath: String
    var isOracle: Bool

    init(id: UUID = UUID(), name: String = "", host: String = "", port: Int = 22, username: String = "ubuntu", keyPath: String = "", serverPath: String = "", isOracle: Bool = false) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.username = username
        self.keyPath = keyPath
        self.serverPath = serverPath
        self.isOracle = isOracle
    }
}

class RemoteServerManager: ObservableObject {
    @Published var configs: [RemoteServerConfig] = []
    @Published var status: [UUID: String] = [:]
    @Published var output: [UUID: String] = [:]

    init() {
        loadConfigs()
        if configs.isEmpty {
            configs = []
            saveConfigs()
        }
    }

    func saveConfigs() {
        if let data = try? JSONEncoder().encode(configs) {
            UserDefaults.standard.set(data, forKey: "remoteServers")
        }
    }

    func loadConfigs() {
        if let data = UserDefaults.standard.data(forKey: "remoteServers"),
           let decoded = try? JSONDecoder().decode([RemoteServerConfig].self, from: data) {
            configs = decoded
        }
    }

    func addConfig(_ config: RemoteServerConfig) {
        configs.append(config)
        saveConfigs()
    }

    func deleteConfig(_ id: UUID) {
        configs.removeAll { $0.id == id }
        saveConfigs()
    }

    func sshCommand(for config: RemoteServerConfig, remoteCmd: String) -> [String] {
        var args = ["-o", "StrictHostKeyChecking=accept-new", "-o", "ConnectTimeout=10"]
        if !config.keyPath.isEmpty { args += ["-i", config.keyPath] }
        if config.port != 22 { args += ["-p", "\(config.port)"] }
        args += ["\(config.username)@\(config.host)", remoteCmd]
        return args
    }

    func scpCommand(for config: RemoteServerConfig, local: String, remote: String, toRemote: Bool) -> [String] {
        var args = ["-o", "StrictHostKeyChecking=accept-new", "-o", "ConnectTimeout=10"]
        if !config.keyPath.isEmpty { args += ["-i", config.keyPath] }
        if config.port != 22 { args += ["-P", "\(config.port)"] }
        if toRemote {
            args += [local, "\(config.username)@\(config.host):\(remote)"]
        } else {
            args += ["\(config.username)@\(config.host):\(remote)", local]
        }
        return args
    }

    @discardableResult
    func runSSH(_ config: RemoteServerConfig, command: String, completion: @escaping (String) -> Void = { _ in }) -> Process {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
        task.arguments = sshCommand(for: config, remoteCmd: command)

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        DispatchQueue.main.async { self.status[config.id] = "Running..." }

        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if let text = String(data: data, encoding: .utf8), !text.isEmpty {
                DispatchQueue.main.async {
                    self.output[config.id] = (self.output[config.id] ?? "") + text
                    completion(text)
                }
            }
        }

        task.terminationHandler = { _ in
            pipe.fileHandleForReading.readabilityHandler = nil
            DispatchQueue.main.async {
                self.status[config.id] = task.terminationStatus == 0 ? "Done" : "Error (\(task.terminationStatus))"
            }
        }

        try? task.run()
        return task
    }

    func testConnection(_ config: RemoteServerConfig, completion: @escaping (Bool, String) -> Void) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
        task.arguments = sshCommand(for: config, remoteCmd: "echo 'connected' && uname -a")

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        DispatchQueue.main.async { self.status[config.id] = "Testing..." }

        task.terminationHandler = { _ in
            pipe.fileHandleForReading.readabilityHandler = nil
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let out = String(data: data, encoding: .utf8) ?? ""
            DispatchQueue.main.async {
                if task.terminationStatus == 0 {
                    self.status[config.id] = "Connected"
                    completion(true, out.trimmingCharacters(in: .whitespacesAndNewlines))
                } else {
                    self.status[config.id] = "Failed"
                    completion(false, out.trimmingCharacters(in: .whitespacesAndNewlines))
                }
            }
        }
        try? task.run()
    }

    func listRemoteFiles(_ config: RemoteServerConfig, path: String, completion: @escaping ([String]) -> Void) {
        runSSH(config, command: "ls -lh '\(path)'") { output in
            let lines = output.components(separatedBy: .newlines).filter { !$0.isEmpty }
            completion(lines)
        }
    }

    func uploadFile(_ config: RemoteServerConfig, localPath: String, remotePath: String, completion: @escaping (Bool) -> Void) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/scp")
        task.arguments = scpCommand(for: config, local: localPath, remote: remotePath, toRemote: true)

        DispatchQueue.main.async { self.status[config.id] = "Uploading..." }

        task.terminationHandler = { _ in
            DispatchQueue.main.async {
                self.status[config.id] = task.terminationStatus == 0 ? "Uploaded" : "Upload failed"
                completion(task.terminationStatus == 0)
            }
        }
        try? task.run()
    }

    func downloadFile(_ config: RemoteServerConfig, remotePath: String, localPath: String, completion: @escaping (Bool) -> Void) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/scp")
        task.arguments = scpCommand(for: config, local: localPath, remote: remotePath, toRemote: false)

        DispatchQueue.main.async { self.status[config.id] = "Downloading..." }

        task.terminationHandler = { _ in
            DispatchQueue.main.async {
                self.status[config.id] = task.terminationStatus == 0 ? "Downloaded" : "Download failed"
                completion(task.terminationStatus == 0)
            }
        }
        try? task.run()
    }
}
