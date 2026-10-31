import SwiftUI
import AppKit
import Combine

// MARK: - Sound Pack Metadata Definition
public struct ThockPackMeta: Identifiable, Hashable {
    public var id: String { name }
    public let name: String
    public let displayName: String
    public let switchType: String
    public let acousticProfile: String
    public let isFavorite: Bool
    
    public init(name: String, displayName: String, switchType: String, acousticProfile: String, isFavorite: Bool) {
        self.name = name
        self.displayName = displayName
        self.switchType = switchType
        self.acousticProfile = acousticProfile
        self.isFavorite = isFavorite
    }
}

// MARK: - Thock Engine Process Manager (CLI Connectivity)
@MainActor
public final class ThockManager: ObservableObject {
    public static let shared = ThockManager()
    
    // File Paths
    public let projectDir = URL(fileURLWithPath: "/Users/dharmitparmar/Doc/KeySound")
    public let binaryURL = URL(fileURLWithPath: "/Users/dharmitparmar/Doc/KeySound/target/release/thock-cli")
    public let packsDir = URL(fileURLWithPath: "/Users/dharmitparmar/Doc/KeySound/packs")
    public let settingsURL = URL(fileURLWithPath: "/Users/dharmitparmar/Doc/KeySound/packs/.settings.json")
    public let favoritesURL = URL(fileURLWithPath: "/Users/dharmitparmar/Doc/KeySound/packs/.favorites.json")
    
    // Process State
    @Published public var isRunning: Bool = false
    @Published public var processPID: Int32? = nil
    @Published public var currentPack: String = "banana_split_lubed"
    @Published public var volume: Double = 80.0
    
    // ASMR Ambient State
    @Published public var rainActive: Bool = false
    @Published public var windActive: Bool = false
    @Published public var thunderActive: Bool = false
    
    // Pack Catalog & Favorites
    @Published public var availablePacks: [ThockPackMeta] = []
    @Published public var favoritePacks: Set<String> = []
    
    // Terminal Log Stream & Command Input
    @Published public var terminalLogs: [String] = []
    @Published public var cliCommandInput: String = ""
    @Published public var statusSubtitle: String = "Zero-Latency Keyboard Engine"
    
    // Internal process handles
    private var process: Process?
    private var inPipe: Pipe?
    private var outPipe: Pipe?
    private var heartbeatTimer: AnyCancellable?
    private var logBufferQueue = DispatchQueue(label: "com.notch.thock.logqueue", qos: .userInitiated)
    
    private init() {
        loadPacksFromDisk()
        loadFavoritesFromDisk()
        loadSettingsFromDisk()
        checkRunningProcess()
        
        // Periodic heartbeat monitor (detects external starts, crashes, or quits)
        heartbeatTimer = Timer.publish(every: 2.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.checkRunningProcess()
            }
    }
    
    // MARK: - Pack Discovery & Settings Sync
    public func loadPacksFromDisk() {
        var names: [String] = []
        if let entries = try? FileManager.default.contentsOfDirectory(at: packsDir, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsHiddenFiles) {
            for entry in entries {
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: entry.path, isDirectory: &isDir), isDir.boolValue {
                    names.append(entry.lastPathComponent)
                }
            }
        }
        
        let favs = favoritePacks
        self.availablePacks = names.sorted(by: { a, b in
            let aFav = favs.contains(a)
            let bFav = favs.contains(b)
            if aFav != bFav { return aFav }
            return a < b
        }).map { name in
            let display = name.replacingOccurrences(of: "_", with: " ").capitalized
            let meta = ThockManager.knownPackMetadata(for: name)
            return ThockPackMeta(
                name: name,
                displayName: display,
                switchType: meta.switchType,
                acousticProfile: meta.profile,
                isFavorite: favs.contains(name)
            )
        }
    }
    
    public func loadFavoritesFromDisk() {
        if let data = try? Data(contentsOf: favoritesURL),
           let favs = try? JSONDecoder().decode(Set<String>.self, from: data) {
            self.favoritePacks = favs
        }
    }
    
    public func loadSettingsFromDisk() {
        struct Settings: Codable {
            let volume: Double
            let pack: String
        }
        if let data = try? Data(contentsOf: settingsURL),
           let s = try? JSONDecoder().decode(Settings.self, from: data) {
            self.volume = s.volume
            self.currentPack = s.pack
        }
    }
    
    public func saveSettingsToDisk() {
        struct Settings: Codable {
            let volume: Double
            let pack: String
        }
        let s = Settings(volume: self.volume, pack: self.currentPack)
        if let data = try? JSONEncoder().encode(s) {
            try? data.write(to: settingsURL)
        }
    }
    
    // MARK: - Process Execution (Start & Stop)
    public func startEngine() {
        guard !isRunning else { return }
        FeedbackManager.playClick()
        
        // Ensure binary is available
        guard FileManager.default.fileExists(atPath: binaryURL.path) else {
            appendLog("❌ Binary missing at \(binaryURL.path). Build with 'cargo build --release' in KeySound.")
            return
        }
        
        let proc = Process()
        proc.executableURL = binaryURL
        proc.currentDirectoryURL = projectDir
        
        var env = ProcessInfo.processInfo.environment
        env["TERM"] = "xterm-256color"
        proc.environment = env
        
        let inP = Pipe()
        let outP = Pipe()
        proc.standardInput = inP
        proc.standardOutput = outP
        proc.standardError = outP
        
        self.inPipe = inP
        self.outPipe = outP
        self.process = proc
        
        outP.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let rawStr = String(data: data, encoding: .utf8) else { return }
            
            // Clean ANSI formatting for pristine GUI terminal rendering
            let clean = rawStr.replacingOccurrences(of: #"\x1b\[[0-9;]*[a-zA-Z]"#, with: "", options: .regularExpression)
            
            DispatchQueue.main.async {
                self?.appendLog(clean)
                self?.parseOutputTelemetry(clean)
            }
        }
        
        proc.terminationHandler = { [weak self] p in
            DispatchQueue.main.async {
                self?.isRunning = false
                self?.processPID = nil
                self?.statusSubtitle = "Engine Stopped"
                self?.appendLog("· thock-cli stopped (exit code: \(p.terminationStatus))")
            }
        }
        
        do {
            try proc.run()
            self.isRunning = true
            self.processPID = proc.processIdentifier
            self.statusSubtitle = "Active · PID \(proc.processIdentifier)"
            FeedbackManager.playSuccess()
            appendLog("🚀 Thock CLI Engine launched [PID: \(proc.processIdentifier)]")
        } catch {
            self.isRunning = false
            self.processPID = nil
            appendLog("❌ Failed to launch thock-cli: \(error.localizedDescription)")
        }
    }
    
    public func stopEngine() {
        FeedbackManager.playClick()
        guard isRunning else {
            // Check if external process is lingering and kill it
            if let pid = processPID {
                kill(pid, SIGTERM)
                self.processPID = nil
                self.isRunning = false
            }
            return
        }
        
        // Send graceful 'exit' command over standard input
        sendCommand("exit", echo: false)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            guard let self = self else { return }
            if self.process?.isRunning == true {
                self.process?.terminate()
            }
            self.isRunning = false
            self.processPID = nil
            self.statusSubtitle = "Engine Stopped"
        }
    }
    
    public func toggleEngine() {
        if isRunning {
            stopEngine()
        } else {
            startEngine()
        }
    }
    
    // MARK: - Process Communication (Standard Input)
    public func sendCommand(_ cmd: String, echo: Bool = true) {
        let trimmed = cmd.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        if echo {
            appendLog("thock › \(trimmed)")
        }
        
        if let inPipe = self.inPipe, isRunning {
            if let data = "\(trimmed)\n".data(using: .utf8) {
                try? inPipe.fileHandleForWriting.write(contentsOf: data)
            }
        } else {
            appendLog("⚠️ Engine is not running. Click 'Start Engine' to execute.")
        }
    }
    
    // MARK: - High-Level Controls
    public func selectPack(_ packName: String) {
        guard currentPack != packName else { return }
        self.currentPack = packName
        saveSettingsToDisk()
        FeedbackManager.playDrop()
        
        if isRunning {
            sendCommand("pack \(packName)", echo: false)
        }
        statusSubtitle = "Pack: \(packName.replacingOccurrences(of: "_", with: " ").capitalized)"
    }
    
    public func updateVolume(_ newVol: Double) {
        self.volume = newVol
        saveSettingsToDisk()
        
        if isRunning {
            let intVol = Int(newVol.rounded())
            sendCommand("vol \(intVol)", echo: false)
        }
    }
    
    public func toggleRain() {
        rainActive.toggle()
        FeedbackManager.playClick()
        if isRunning {
            sendCommand("asmr rain \(rainActive ? "on" : "off")", echo: false)
        }
    }
    
    public func toggleWind() {
        windActive.toggle()
        FeedbackManager.playClick()
        if isRunning {
            sendCommand("asmr wind \(windActive ? "on" : "off")", echo: false)
        }
    }
    
    public func toggleThunder() {
        thunderActive.toggle()
        FeedbackManager.playClick()
        if isRunning {
            sendCommand("asmr thunder \(thunderActive ? "on" : "off")", echo: false)
        }
    }
    
    public func toggleFavorite(_ packName: String) {
        if favoritePacks.contains(packName) {
            favoritePacks.remove(packName)
        } else {
            favoritePacks.insert(packName)
        }
        if let data = try? JSONEncoder().encode(favoritePacks) {
            try? data.write(to: favoritesURL)
        }
        loadPacksFromDisk()
        FeedbackManager.playClick()
    }
    
    public func clearTerminal() {
        terminalLogs.removeAll()
        FeedbackManager.playClick()
    }
    
    // MARK: - Internal Helpers
    private func appendLog(_ text: String) {
        let lines = text.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty {
                terminalLogs.append(trimmed)
            }
        }
        // Retain max 300 lines for zero memory pressure
        if terminalLogs.count > 300 {
            terminalLogs.removeFirst(terminalLogs.count - 300)
        }
    }
    
    private func parseOutputTelemetry(_ text: String) {
        if text.contains("Rain [ON") { self.rainActive = true }
        if text.contains("Rain [OFF") { self.rainActive = false }
        if text.contains("Wind [ON") { self.windActive = true }
        if text.contains("Wind [OFF") { self.windActive = false }
        if text.contains("Thunder [ON") { self.thunderActive = true }
        if text.contains("Thunder [OFF") { self.thunderActive = false }
    }
    
    private func checkRunningProcess() {
        // Run a lightweight pgrep to detect if thock-cli is running
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        task.arguments = ["-x", "thock-cli"]
        let out = Pipe()
        task.standardOutput = out
        
        do {
            try task.run()
            task.waitUntilExit()
            if task.terminationStatus == 0 {
                let data = out.fileHandleForReading.readDataToEndOfFile()
                if let str = String(data: data, encoding: .utf8),
                   let firstPIDStr = str.components(separatedBy: .newlines).first,
                   let pid = Int32(firstPIDStr.trimmingCharacters(in: .whitespaces)) {
                    if !self.isRunning {
                        self.isRunning = true
                        self.processPID = pid
                        self.statusSubtitle = "Active · PID \(pid)"
                    }
                }
            } else if self.process == nil || self.process?.isRunning == false {
                if self.isRunning {
                    self.isRunning = false
                    self.processPID = nil
                    self.statusSubtitle = "Engine Offline"
                }
            }
        } catch {
            // Ignore pgrep failure
        }
    }
    
    private static func knownPackMetadata(for name: String) -> (switchType: String, profile: String) {
        switch name {
        case "bubble_heaven":
            return ("Custom Linear", "Zoom 75 + WS Morandi bubbly pop")
        case "creamy_butter":
            return ("Custom Linear", "Feather Lubed whisper-soft travel")
        case "creamy_lite_calm":
            return ("Light Linear", "Gentle, soothing acoustic report")
        case "banana_split_lubed":
            return ("Machined Linear", "C³Equalz 62g marbled acoustic clack")
        case "nk_cream":
            return ("POM Linear", "NovelKeys Cream deep acoustic thud")
        case "overlubed_custom":
            return ("Krytox 205g0", "Ultra-muted deep butter thock")
        case "tealios_v2":
            return ("Premium Linear", "ZealPC 67g crisp glassy return")
        case "cherry_mx_red_pbt":
            return ("Classic Linear", "PBT doubleshot firm bottom-out")
        case "cherry_mx_red_abs":
            return ("Classic Linear", "ABS keycaps bright snappy pop")
        case "cherry_mx_brown_pbt":
            return ("Light Tactile", "PBT woody tactile resonance")
        case "cherry_mx_brown_abs":
            return ("Light Tactile", "Crisp tactile feedback report")
        case "cherry_mx_black_pbt":
            return ("Heavy Linear", "Vintage weighted authoritative thud")
        case "steelseries_apex_pro_v2":
            return ("Hall Effect", "OmniPoint magnetic acoustic snap")
        case "animal_crossing_nl":
            return ("Novelty Soundscape", "Playful Nintendo acoustic blips")
        default:
            return ("Mechanical Switch", "High-fidelity acoustic capture")
        }
    }
}

// MARK: - Notch Module Conformance
@MainActor
public final class ThockModule: NotchModule {
    public static let shared = ThockModule()
    
    public let id = "thock"
    public let title = "Thock"
    public let iconName = "keyboard"
    @Published public var isEnabled: Bool = true
    
    public var statusSubtitle: String {
        ThockManager.shared.statusSubtitle
    }
    
    public init() {}
    
    public func start() {
        // Module focused: reload settings and state
        ThockManager.shared.loadPacksFromDisk()
        ThockManager.shared.loadSettingsFromDisk()
    }
    
    public func stop() {
        // Do NOT stop the background audio engine when switching tabs!
        // The user wants thock to continue playing while they type across macOS!
    }
    
    public func terminateProcess() {
        ThockManager.shared.stopEngine()
    }
    
    public func makeCompactView() -> AnyView {
        AnyView(
            HStack(spacing: 5) {
                Image(systemName: "keyboard")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundColor(ThockManager.shared.isRunning ? DesignSystem.accentColor : Color.white.opacity(0.8))
                
                Text("Thock")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                
                if ThockManager.shared.isRunning {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 5, height: 5)
                        .shadow(color: Color.green.opacity(0.8), radius: 3)
                }
            }
        )
    }
    
    public func makeExpandedView() -> AnyView {
        AnyView(
            ThockExpandedView(manager: ThockManager.shared)
        )
    }
}

// MARK: - Thock Expanded View (Hardware Control & Terminal Console)
public struct ThockExpandedView: View {
    @ObservedObject var manager: ThockManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    public var body: some View {
        HStack(spacing: 12) {
            // LEFT COLUMN: Hardware Controls & ASMR Layers (Width ~215pt)
            VStack(alignment: .leading, spacing: 8) {
                // Header & Status Pill
                HStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(LinearGradient(
                                colors: [Color.white.opacity(0.12), Color.white.opacity(0.04)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 30, height: 30)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.8)
                            )
                        
                        Image(systemName: "keyboard.fill")
                            .font(.system(size: 14))
                            .foregroundColor(manager.isRunning ? DesignSystem.accentColor : Color.white.opacity(0.7))
                    }
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Thock Audio")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        HStack(spacing: 4) {
                            Circle()
                                .fill(manager.isRunning ? Color.green : Color.white.opacity(0.3))
                                .frame(width: 6, height: 6)
                                .shadow(color: manager.isRunning ? Color.green.opacity(0.8) : Color.clear, radius: 4)
                            
                            Text(manager.isRunning ? "Running (PID \(manager.processPID ?? 0))" : "Engine Offline")
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundColor(manager.isRunning ? Color.green : DesignSystem.secondaryText)
                        }
                    }
                }
                
                // Primary Action Button (Start / Stop)
                Button(action: { manager.toggleEngine() }) {
                    HStack(spacing: 6) {
                        Image(systemName: manager.isRunning ? "stop.fill" : "play.fill")
                            .font(.system(size: 10, weight: .bold))
                        
                        Text(manager.isRunning ? "Stop Engine" : "Start Engine")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(manager.isRunning ? Color.white : Color.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(
                        Capsule()
                            .fill(manager.isRunning ? Color.red.opacity(0.8) : DesignSystem.accentColor)
                    )
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.white.opacity(manager.isRunning ? 0.3 : 0.6), lineWidth: 0.8)
                    )
                    .shadow(color: (manager.isRunning ? Color.red : DesignSystem.accentColor).opacity(0.25), radius: 6, y: 2)
                }
                .buttonStyle(.spring)
                
                // Master Volume Slider
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 9))
                            .foregroundColor(DesignSystem.accentColor)
                        
                        Text("Master Volume")
                            .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.9))
                        
                        Spacer()
                        
                        Text("\(Int(manager.volume))%")
                            .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                            .foregroundColor(DesignSystem.accentColor)
                    }
                    
                    Slider(value: $manager.volume, in: 0...100, step: 1) {
                        Text("Volume")
                    } onEditingChanged: { editing in
                        if !editing {
                            manager.updateVolume(manager.volume)
                        }
                    }
                    .accentColor(DesignSystem.accentColor)
                }
                .padding(7)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.8)
                )
                
                // Ambient ASMR Mini-Mixer
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ambient Psychoacoustics")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundColor(DesignSystem.secondaryText)
                    
                    HStack(spacing: 5) {
                        AsmrPillButton(
                            title: "Rain",
                            icon: "cloud.rain.fill",
                            isActive: manager.rainActive,
                            activeColor: Color(red: 0.3, green: 0.75, blue: 1.0),
                            action: { manager.toggleRain() }
                        )
                        
                        AsmrPillButton(
                            title: "Wind",
                            icon: "wind",
                            isActive: manager.windActive,
                            activeColor: Color(red: 0.5, green: 0.85, blue: 0.9),
                            action: { manager.toggleWind() }
                        )
                        
                        AsmrPillButton(
                            title: "Thunder",
                            icon: "bolt.fill",
                            isActive: manager.thunderActive,
                            activeColor: Color(red: 1.0, green: 0.82, blue: 0.3),
                            action: { manager.toggleThunder() }
                        )
                    }
                }
                .padding(7)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.8)
                )
            }
            .frame(width: 205)
            
            // RIGHT COLUMN: Sound Packs & Live Terminal Window (Width ~380pt)
            VStack(alignment: .leading, spacing: 8) {
                // Sound Pack Selector Row
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Sound Packs")
                            .font(.system(size: 10.5, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Text("\(manager.availablePacks.count) Available")
                            .font(.system(size: 8.5, weight: .medium))
                            .foregroundColor(DesignSystem.secondaryText)
                    }
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(manager.availablePacks) { pack in
                                let isSelected = (manager.currentPack == pack.name)
                                Button(action: { manager.selectPack(pack.name) }) {
                                    HStack(spacing: 5) {
                                        if pack.isFavorite {
                                            Image(systemName: "star.fill")
                                                .font(.system(size: 7.5))
                                                .foregroundColor(Color.yellow)
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(pack.displayName)
                                                .font(.system(size: 9.5, weight: isSelected ? .bold : .medium, design: .rounded))
                                                .foregroundColor(isSelected ? .white : Color.white.opacity(0.85))
                                                .lineLimit(1)
                                            
                                            Text(pack.switchType)
                                                .font(.system(size: 7.5, weight: .regular))
                                                .foregroundColor(isSelected ? DesignSystem.accentColor : DesignSystem.secondaryText)
                                                .lineLimit(1)
                                        }
                                        
                                        if isSelected {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 8, weight: .bold))
                                                .foregroundColor(DesignSystem.accentColor)
                                                .padding(.leading, 2)
                                        }
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(isSelected ? DesignSystem.structureColor : Color.white.opacity(0.05))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .strokeBorder(isSelected ? DesignSystem.accentColor : Color.white.opacity(0.08), lineWidth: isSelected ? 1.2 : 0.8)
                                    )
                                }
                                .buttonStyle(.spring)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .frame(height: 38)
                }
                
                // Live Interactive Terminal Console Window
                VStack(spacing: 0) {
                    // Terminal Window Header Bar
                    HStack(spacing: 6) {
                        // Window controls (Red / Yellow / Green micro-dots)
                        Circle().fill(Color(red: 1.0, green: 0.37, blue: 0.34)).frame(width: 7, height: 7)
                        Circle().fill(Color(red: 1.0, green: 0.74, blue: 0.18)).frame(width: 7, height: 7)
                        Circle().fill(Color(red: 0.15, green: 0.79, blue: 0.25)).frame(width: 7, height: 7)
                        
                        Text("thock-cli — interactive session")
                            .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                            .foregroundColor(Color.white.opacity(0.6))
                            .padding(.leading, 4)
                        
                        Spacer()
                        
                        Button(action: { manager.clearTerminal() }) {
                            HStack(spacing: 3) {
                                Image(systemName: "trash")
                                    .font(.system(size: 7))
                                Text("Clear")
                                    .font(.system(size: 7.5, weight: .medium))
                            }
                            .foregroundColor(Color.white.opacity(0.5))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.white.opacity(0.05)))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.04))
                    
                    // Console Output Log View
                    ScrollViewReader { proxy in
                        ScrollView(.vertical, showsIndicators: true) {
                            LazyVStack(alignment: .leading, spacing: 2) {
                                if manager.terminalLogs.isEmpty {
                                    Text("thock-cli offline. Press 'Start Engine' to launch.")
                                        .font(.system(size: 8.5, design: .monospaced))
                                        .foregroundColor(Color.white.opacity(0.4))
                                        .padding(6)
                                } else {
                                    ForEach(Array(manager.terminalLogs.enumerated()), id: \.offset) { index, line in
                                        Text(line)
                                            .font(.system(size: 8.5, weight: .regular, design: .monospaced))
                                            .foregroundColor(terminalLineColor(for: line))
                                            .textSelection(.enabled)
                                            .id(index)
                                    }
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                        }
                        .frame(maxHeight: 90)
                        .onChange(of: manager.terminalLogs.count) { _, newCount in
                            if newCount > 0 {
                                withAnimation {
                                    proxy.scrollTo(newCount - 1, anchor: .bottom)
                                }
                            }
                        }
                    }
                    
                    // Terminal Input Prompt
                    HStack(spacing: 5) {
                        Text("thock ›")
                            .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                            .foregroundColor(DesignSystem.accentColor)
                        
                        TextField("Type command (e.g. status, help, vol 90)...", text: $manager.cliCommandInput)
                            .font(.system(size: 8.5, design: .monospaced))
                            .textFieldStyle(.plain)
                            .foregroundColor(.white)
                            .onSubmit {
                                let cmd = manager.cliCommandInput
                                manager.cliCommandInput = ""
                                manager.sendCommand(cmd)
                            }
                        
                        if !manager.cliCommandInput.isEmpty {
                            Button(action: {
                                let cmd = manager.cliCommandInput
                                manager.cliCommandInput = ""
                                manager.sendCommand(cmd)
                            }) {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(DesignSystem.accentColor)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.black.opacity(0.4))
                }
                .background(Color.black.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.8)
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(4)
    }
    
    private func terminalLineColor(for line: String) -> Color {
        if line.hasPrefix("thock ›") {
            return DesignSystem.accentColor
        } else if line.contains("✓") || line.contains("Running") || line.contains("Active") {
            return Color(red: 0.35, green: 0.9, blue: 0.5)
        } else if line.contains("❌") || line.contains("Error") || line.contains("missing") {
            return Color(red: 1.0, green: 0.4, blue: 0.4)
        } else if line.contains("★") || line.contains("Sound Packs") {
            return Color(red: 1.0, green: 0.85, blue: 0.3)
        } else if line.contains("───") {
            return Color.white.opacity(0.2)
        } else {
            return Color.white.opacity(0.85)
        }
    }
}

// MARK: - ASMR Tactile Pill Button
private struct AsmrPillButton: View {
    let title: String
    let icon: String
    let isActive: Bool
    let activeColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 8))
                    .foregroundColor(isActive ? activeColor : Color.white.opacity(0.6))
                
                Text(title)
                    .font(.system(size: 8.5, weight: isActive ? .bold : .medium, design: .rounded))
                    .foregroundColor(isActive ? .white : Color.white.opacity(0.8))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(isActive ? activeColor.opacity(0.2) : Color.white.opacity(0.04))
            )
            .overlay(
                Capsule()
                    .strokeBorder(isActive ? activeColor : Color.white.opacity(0.08), lineWidth: isActive ? 1.0 : 0.6)
            )
        }
        .buttonStyle(.spring)
    }
}
