import SwiftUI
import AppKit
import ApplicationServices
import Combine

// MARK: - Subsections Enum
public enum ThockSubSection: String, CaseIterable, Identifiable {
    case keySound = "Key Sound"
    case asmr = "Ambient ASMR"
    case terminal = "CLI Terminal"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .keySound: return "keyboard"
        case .asmr: return "cloud.rain.fill"
        case .terminal: return "apple.terminal"
        }
    }
}

// MARK: - Sound Pack Metadata
public struct ThockPackMeta: Identifiable, Hashable {
    public var id: String { name }
    public let name: String
    public let displayName: String
    public let switchType: String
    public let acousticProfile: String
    public var isFavorite: Bool
    
    public init(name: String, displayName: String, switchType: String, acousticProfile: String, isFavorite: Bool = false) {
        self.name = name
        self.displayName = displayName
        self.switchType = switchType
        self.acousticProfile = acousticProfile
        self.isFavorite = isFavorite
    }
}

// MARK: - Thock Module & Engine Process Manager
@MainActor
public final class ThockModule: NotchModule {
    public static let shared = ThockModule()
    
    public let id = "thock"
    public let title = "Thock"
    public let iconName = "keyboard"
    @Published public var isEnabled: Bool = true
    
    // File Paths
    public let projectDir = URL(fileURLWithPath: "/Users/dharmitparmar/Doc/KeySound")
    public let binaryURL = URL(fileURLWithPath: "/Users/dharmitparmar/Doc/KeySound/target/release/thock-cli")
    public let packsDir = URL(fileURLWithPath: "/Users/dharmitparmar/Doc/KeySound/packs")
    public let settingsURL = URL(fileURLWithPath: "/Users/dharmitparmar/Doc/KeySound/packs/.settings.json")
    public let favoritesURL = URL(fileURLWithPath: "/Users/dharmitparmar/Doc/KeySound/packs/.favorites.json")
    
    // Active Subsection
    @Published public var selectedSection: ThockSubSection = .keySound
    
    // Permissions State
    @Published public var isAccessibilityGranted: Bool = false
    
    // Engine State
    @Published public var isRunning: Bool = false
    @Published public var processPID: Int32? = nil
    @Published public var statusSubtitle: String = "Engine Offline"
    
    // Dedicated Volume Controls (Key Sound vs ASMR)
    @Published public var keyVolume: Double = 70.0 {
        didSet { volume = keyVolume }
    }
    @Published public var volume: Double = 70.0 // Kept for backwards compatibility
    @Published public var asmrVolume: Double = 50.0
    
    // Switch Pack State
    @Published public var currentPack: String = "nk_cream"
    @Published public var availablePacks: [ThockPackMeta] = []
    @Published public var favoritePacks: Set<String> = []
    
    // ASMR Layer Toggles
    @Published public var rainActive: Bool = false
    @Published public var windActive: Bool = false
    @Published public var thunderActive: Bool = false
    
    // Terminal Log Stream
    @Published public var terminalLogs: [String] = []
    @Published public var cliCommandInput: String = ""
    
    // Process Piping
    private var process: Process?
    private var inPipe: Pipe?
    private var outPipe: Pipe?
    private var heartbeatTimer: AnyCancellable?
    
    public init() {
        // Fast, non-blocking synchronous file reads
        loadPacksFromDisk()
        loadFavoritesFromDisk()
        loadSettingsFromDisk()
        checkAccessibilityStatus()
        
        // Asynchronously check running processes on background queue - NEVER block init or pump runloop
        checkRunningProcessInBackground()
        
        // Periodic background heartbeat (checks process & permissions dynamically)
        heartbeatTimer = Timer.publish(every: 3.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.checkRunningProcessInBackground()
                self?.checkAccessibilityStatus()
            }
    }
    
    // MARK: - NotchModule Protocol Lifecycle
    public func start() {
        loadPacksFromDisk()
        loadSettingsFromDisk()
        checkAccessibilityStatus()
        checkRunningProcessInBackground()
    }
    
    public func stop() {
        // Audio continues in background across macOS typing sessions
    }
    
    public func terminateProcess() {
        stopEngine()
    }
    
    // MARK: - Permissions & TCC Monitoring
    public func checkAccessibilityStatus() {
        self.isAccessibilityGranted = AXIsProcessTrusted()
    }
    
    public func requestAccessibilityPermission() {
        let key = "AXTrustedCheckOptionPrompt" as CFString
        let options = [key: true] as CFDictionary
        let granted = AXIsProcessTrustedWithOptions(options)
        self.isAccessibilityGranted = granted
        if !granted {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    }
    
    public func openInputMonitoringSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEventAccess") {
            NSWorkspace.shared.open(url)
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
            let meta = ThockModule.knownPackMetadata(for: name)
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
            var asmrVolume: Double?
        }
        if let data = try? Data(contentsOf: settingsURL),
           let s = try? JSONDecoder().decode(Settings.self, from: data) {
            self.keyVolume = s.volume
            self.volume = s.volume
            self.currentPack = s.pack
            if let asmr = s.asmrVolume {
                self.asmrVolume = asmr
            }
        }
    }
    
    public func saveSettingsToDisk() {
        struct Settings: Codable {
            let volume: Double
            let pack: String
            let asmrVolume: Double
        }
        let s = Settings(volume: self.keyVolume, pack: self.currentPack, asmrVolume: self.asmrVolume)
        if let data = try? JSONEncoder().encode(s) {
            try? data.write(to: settingsURL)
        }
    }
    
    // MARK: - Direct Audio Audition / Preview
    public func playPackSample(_ packName: String) {
        let packDir = packsDir.appendingPathComponent(packName)
        var wavURL: URL? = nil
        if let files = try? FileManager.default.contentsOfDirectory(at: packDir, includingPropertiesForKeys: nil) {
            wavURL = files.first(where: { $0.pathExtension.lowercased() == "wav" })
        }
        // Fallback for procedural packs (e.g. cherry mx) that don't store standalone wavs
        if wavURL == nil {
            let fallbackDir = packsDir.appendingPathComponent("banana_split_lubed")
            if let files = try? FileManager.default.contentsOfDirectory(at: fallbackDir, includingPropertiesForKeys: nil) {
                wavURL = files.first(where: { $0.pathExtension.lowercased() == "wav" })
            }
        }
        guard let targetURL = wavURL else { return }
        if let sound = NSSound(contentsOf: targetURL, byReference: true) {
            sound.volume = Float(max(0.05, min(1.0, keyVolume / 100.0)))
            sound.play()
        }
    }
    
    public func auditionCurrentPack() {
        playPackSample(currentPack)
    }
    
    // MARK: - Process Execution (Start & Stop)
    public func startEngine() {
        guard !isRunning else { return }
        FeedbackManager.playClick()
        
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
            
            // Sync current volume and asmr state to spawned engine
            let kv = Int(keyVolume.rounded())
            let av = Int(asmrVolume.rounded())
            sendCommand("vol \(kv)", echo: false)
            sendCommand("asmr vol \(av)", echo: false)
            if !currentPack.isEmpty {
                sendCommand("pack \(currentPack)", echo: false)
            }
        } catch {
            self.isRunning = false
            self.processPID = nil
            appendLog("❌ Failed to launch thock-cli: \(error.localizedDescription)")
        }
    }
    
    public func stopEngine() {
        FeedbackManager.playClick()
        guard isRunning else {
            if let pid = processPID {
                kill(pid, SIGTERM)
                self.processPID = nil
                self.isRunning = false
            }
            return
        }
        
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
    
    // MARK: - High-Level Controls (Key Sound & ASMR)
    public func selectPack(_ packName: String) {
        guard currentPack != packName else {
            // Already selected, audition it
            auditionCurrentPack()
            return
        }
        self.currentPack = packName
        saveSettingsToDisk()
        FeedbackManager.playDrop()
        
        // Immediate audible feedback
        playPackSample(packName)
        
        if isRunning {
            sendCommand("pack \(packName)", echo: false)
        }
        statusSubtitle = "Pack: \(packName.replacingOccurrences(of: "_", with: " ").capitalized)"
    }
    
    public func updateKeyVolume(_ newVol: Double) {
        self.keyVolume = newVol
        self.volume = newVol
        saveSettingsToDisk()
        
        if isRunning {
            let intVol = Int(newVol.rounded())
            sendCommand("vol \(intVol)", echo: false)
        }
    }
    
    public func updateVolume(_ newVol: Double) {
        updateKeyVolume(newVol)
    }
    
    public func updateAsmrVolume(_ newVol: Double) {
        self.asmrVolume = newVol
        saveSettingsToDisk()
        
        if isRunning {
            let intVol = Int(newVol.rounded())
            sendCommand("asmr vol \(intVol)", echo: false)
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
    
    public func muteAllAsmr() {
        FeedbackManager.playClick()
        rainActive = false
        windActive = false
        thunderActive = false
        if isRunning {
            sendCommand("asmr none", echo: false)
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
    
    public func checkRunningProcessInBackground() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
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
                        DispatchQueue.main.async {
                            guard let self = self else { return }
                            if !self.isRunning {
                                self.isRunning = true
                                self.processPID = pid
                                self.statusSubtitle = "Active · PID \(pid)"
                            }
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        guard let self = self else { return }
                        if self.process == nil || self.process?.isRunning == false {
                            if self.isRunning {
                                self.isRunning = false
                                self.processPID = nil
                                self.statusSubtitle = "Engine Offline"
                            }
                        }
                    }
                }
            } catch {
                // Ignore pgrep failure
            }
        }
    }
    
    private static func knownPackMetadata(for name: String) -> (switchType: String, profile: String) {
        switch name {
        case "bubble_heaven":
            return ("Custom Linear", "Zoom 75 + WS Morandi bubbly pop")
        case "creamy_butter":
            return ("Custom Linear", "Feather Lubed whisper-soft travel")
        case "creamy_lite_calm":
            return ("Light Linear", "Gentle soothing acoustic report")
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
    
    // MARK: - Compact & Expanded Views
    public func makeCompactView() -> AnyView {
        AnyView(
            HStack(spacing: 5) {
                Image(systemName: "keyboard")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundColor(isRunning ? DesignSystem.accentColor : Color.white.opacity(0.8))
                
                Text("Thock")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                
                if isRunning {
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
            ThockExpandedView(module: self)
        )
    }
}

// MARK: - Thock Expanded View (Hardware Control & Two Subsections)
public struct ThockExpandedView: View {
    @ObservedObject var module: ThockModule
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    public var body: some View {
        VStack(spacing: 8) {
            // SUB-NAVIGATION DOCK: Key Sound · Ambient ASMR · CLI Terminal
            HStack(spacing: 6) {
                ForEach(ThockSubSection.allCases) { section in
                    let isCurrent = (module.selectedSection == section)
                    Button(action: {
                        FeedbackManager.playClick()
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                            module.selectedSection = section
                        }
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: section.icon)
                                .font(.system(size: 9, weight: isCurrent ? .bold : .medium))
                            Text(section.rawValue)
                                .font(.system(size: 10, weight: isCurrent ? .bold : .medium, design: .rounded))
                        }
                        .foregroundColor(isCurrent ? .white : Color.white.opacity(0.6))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4.5)
                        .background(
                            Capsule()
                                .fill(isCurrent ? DesignSystem.structureColor : Color.white.opacity(0.04))
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(isCurrent ? DesignSystem.accentColor : Color.white.opacity(0.08), lineWidth: isCurrent ? 1.0 : 0.6)
                        )
                    }
                    .buttonStyle(.spring)
                }
                
                Spacer()
                
                // Live Engine Status Pill
                HStack(spacing: 4) {
                    Circle()
                        .fill(module.isRunning ? Color.green : Color.white.opacity(0.3))
                        .frame(width: 6, height: 6)
                        .shadow(color: module.isRunning ? Color.green.opacity(0.8) : Color.clear, radius: 4)
                    
                    Text(module.isRunning ? "PID \(module.processPID ?? 0)" : "Offline")
                        .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                        .foregroundColor(module.isRunning ? Color.green : DesignSystem.secondaryText)
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 3.5)
                .background(Capsule().fill(Color.white.opacity(0.04)))
            }
            .padding(.horizontal, 4)
            
            // SUBSECTION CONTENT
            switch module.selectedSection {
            case .keySound:
                keySoundSectionView
            case .asmr:
                asmrSectionView
            case .terminal:
                terminalSectionView
            }
        }
        .padding(4)
    }
    
    // MARK: - Subsection 1: Key Sound View
    private var keySoundSectionView: some View {
        VStack(spacing: 8) {
            // Permission Alert Banner if untrusted
            if !module.isAccessibilityGranted {
                HStack(spacing: 8) {
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color(red: 1.0, green: 0.75, blue: 0.2))
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Accessibility & Input Monitoring Required")
                            .font(.system(size: 9.5, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("macOS requires permission to detect typing across apps and play key sounds.")
                            .font(.system(size: 8, weight: .regular))
                            .foregroundColor(Color.white.opacity(0.75))
                    }
                    
                    Spacer()
                    
                    Button(action: { module.requestAccessibilityPermission() }) {
                        Text("Grant Access")
                            .font(.system(size: 8.5, weight: .bold, design: .rounded))
                            .foregroundColor(.black)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color(red: 1.0, green: 0.8, blue: 0.2)))
                    }
                    .buttonStyle(.spring)
                    
                    Button(action: { module.openInputMonitoringSettings() }) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(4)
                            .background(Circle().fill(Color.white.opacity(0.1)))
                    }
                    .buttonStyle(.spring)
                    .help("Open Input Monitoring in System Settings")
                }
                .padding(6)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(red: 0.9, green: 0.6, blue: 0.1).opacity(0.15))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color(red: 1.0, green: 0.75, blue: 0.2).opacity(0.3), lineWidth: 0.8)
                )
            }
            
            // Top Controls Bar: Engine Power, Audition Sound & Key Sound Volume
            HStack(spacing: 10) {
                // Engine Start / Stop Button
                Button(action: { module.toggleEngine() }) {
                    HStack(spacing: 5) {
                        Image(systemName: module.isRunning ? "stop.fill" : "play.fill")
                            .font(.system(size: 9, weight: .bold))
                        Text(module.isRunning ? "Stop Engine" : "Start Engine")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(module.isRunning ? Color.white : Color.black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(module.isRunning ? Color.red.opacity(0.85) : DesignSystem.accentColor)
                    )
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.white.opacity(0.4), lineWidth: 0.8)
                    )
                    .shadow(color: (module.isRunning ? Color.red : DesignSystem.accentColor).opacity(0.25), radius: 5, y: 1)
                }
                .buttonStyle(.spring)
                
                // Audition Current Pack Sound Button
                Button(action: { module.auditionCurrentPack() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "speaker.wave.3.fill")
                            .font(.system(size: 9))
                            .foregroundColor(DesignSystem.accentColor)
                        Text("Audition Tap")
                            .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5.5)
                    .background(Capsule().fill(Color.white.opacity(0.06)))
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 0.8))
                }
                .buttonStyle(.spring)
                .help("Play an instant acoustic preview of the active switch")
                
                Spacer()
                
                // Key Sound Volume Slider
                HStack(spacing: 6) {
                    Image(systemName: "keyboard.fill")
                        .font(.system(size: 9))
                        .foregroundColor(DesignSystem.accentColor)
                    
                    Text("Key Vol")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.85))
                    
                    Slider(value: $module.keyVolume, in: 0...100, step: 1) {
                        Text("Key Volume")
                    } onEditingChanged: { editing in
                        if !editing {
                            module.updateKeyVolume(module.keyVolume)
                        }
                    }
                    .frame(width: 90)
                    .accentColor(DesignSystem.accentColor)
                    
                    Text("\(Int(module.keyVolume))%")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(DesignSystem.accentColor)
                        .frame(width: 32, alignment: .trailing)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.04)))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.white.opacity(0.08), lineWidth: 0.8))
            }
            
            // Sound Pack Selector Carousel & Profiles (14 Switch Types)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Mechanical Switch Profiles")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text("Selected: \(module.currentPack.replacingOccurrences(of: "_", with: " ").capitalized)")
                        .font(.system(size: 8.5, weight: .medium, design: .rounded))
                        .foregroundColor(DesignSystem.accentColor)
                }
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(module.availablePacks) { pack in
                            let isSelected = (module.currentPack == pack.name)
                            Button(action: {
                                module.selectPack(pack.name)
                            }) {
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 4) {
                                        if pack.isFavorite {
                                            Image(systemName: "star.fill")
                                                .font(.system(size: 7))
                                                .foregroundColor(Color.yellow)
                                        }
                                        
                                        Text(pack.displayName)
                                            .font(.system(size: 9.5, weight: isSelected ? .bold : .medium, design: .rounded))
                                            .foregroundColor(isSelected ? .white : Color.white.opacity(0.9))
                                            .lineLimit(1)
                                        
                                        Spacer(minLength: 0)
                                        
                                        if isSelected {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.system(size: 8))
                                                .foregroundColor(DesignSystem.accentColor)
                                        }
                                    }
                                    
                                    Text(pack.switchType)
                                        .font(.system(size: 7.5, weight: .semibold))
                                        .foregroundColor(isSelected ? DesignSystem.accentColor : DesignSystem.secondaryText)
                                        .lineLimit(1)
                                    
                                    Text(pack.acousticProfile)
                                        .font(.system(size: 7, weight: .regular))
                                        .foregroundColor(Color.white.opacity(0.55))
                                        .lineLimit(1)
                                }
                                .frame(width: 135, alignment: .leading)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(isSelected ? DesignSystem.structureColor : Color.white.opacity(0.04))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .strokeBorder(isSelected ? DesignSystem.accentColor : Color.white.opacity(0.08), lineWidth: isSelected ? 1.2 : 0.8)
                                )
                            }
                            .buttonStyle(.spring)
                            .contextMenu {
                                Button(action: { module.toggleFavorite(pack.name) }) {
                                    Label(pack.isFavorite ? "Unfavorite" : "Favorite", systemImage: pack.isFavorite ? "star.slash" : "star")
                                }
                                Button(action: { module.playPackSample(pack.name) }) {
                                    Label("Audition Sound", systemImage: "speaker.wave.2")
                                }
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(height: 52)
            }
        }
    }
    
    // MARK: - Subsection 2: Ambient ASMR View
    private var asmrSectionView: some View {
        VStack(spacing: 8) {
            // ASMR Volume & Mute Controls
            HStack(spacing: 10) {
                // ASMR Ambient Volume Slider
                HStack(spacing: 6) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 9))
                        .foregroundColor(Color(red: 0.35, green: 0.8, blue: 1.0))
                    
                    Text("ASMR Vol")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.85))
                    
                    Slider(value: $module.asmrVolume, in: 0...100, step: 1) {
                        Text("ASMR Volume")
                    } onEditingChanged: { editing in
                        if !editing {
                            module.updateAsmrVolume(module.asmrVolume)
                        }
                    }
                    .frame(width: 110)
                    .accentColor(Color(red: 0.35, green: 0.8, blue: 1.0))
                    
                    Text("\(Int(module.asmrVolume))%")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(red: 0.35, green: 0.8, blue: 1.0))
                        .frame(width: 32, alignment: .trailing)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.04)))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.white.opacity(0.08), lineWidth: 0.8))
                
                Spacer()
                
                // Mute All ASMR Button
                Button(action: { module.muteAllAsmr() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "speaker.slash")
                            .font(.system(size: 8.5))
                        Text("Mute All")
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(Color.white.opacity(0.7))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4.5)
                    .background(Capsule().fill(Color.white.opacity(0.05)))
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.1), lineWidth: 0.8))
                }
                .buttonStyle(.spring)
                .help("Mute all active ASMR ambient soundscapes")
            }
            
            // Bento Cards for Rain, Wind, Thunder Soundscapes
            HStack(spacing: 8) {
                // Rain Card
                AsmrLayerCard(
                    title: "Rain Field",
                    description: "Continuous soothing rainfall",
                    icon: "cloud.rain.fill",
                    isActive: module.rainActive,
                    activeColor: Color(red: 0.3, green: 0.75, blue: 1.0),
                    action: { module.toggleRain() }
                )
                
                // Wind Card
                AsmrLayerCard(
                    title: "Organic Wind",
                    description: "Breathing gusts & aerodynamic LFO",
                    icon: "wind",
                    isActive: module.windActive,
                    activeColor: Color(red: 0.45, green: 0.85, blue: 0.95),
                    action: { module.toggleWind() }
                )
                
                // Thunder Card
                AsmrLayerCard(
                    title: "Thunder Strike",
                    description: "Seismic strikes & low rumblings",
                    icon: "bolt.fill",
                    isActive: module.thunderActive,
                    activeColor: Color(red: 1.0, green: 0.82, blue: 0.3),
                    action: { module.toggleThunder() }
                )
            }
            .frame(height: 52)
        }
    }
    
    // MARK: - Subsection 3: CLI Terminal View
    private var terminalSectionView: some View {
        VStack(spacing: 0) {
            // Terminal Window Header Bar
            HStack(spacing: 6) {
                Circle().fill(Color(red: 1.0, green: 0.37, blue: 0.34)).frame(width: 7, height: 7)
                Circle().fill(Color(red: 1.0, green: 0.74, blue: 0.18)).frame(width: 7, height: 7)
                Circle().fill(Color(red: 0.15, green: 0.79, blue: 0.25)).frame(width: 7, height: 7)
                
                Text("thock-cli — interactive session")
                    .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.6))
                    .padding(.leading, 4)
                
                Spacer()
                
                Button(action: { module.clearTerminal() }) {
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
                        if module.terminalLogs.isEmpty {
                            Text("thock-cli ready. Press 'Start Engine' in Key Sound tab to begin.")
                                .font(.system(size: 8.5, design: .monospaced))
                                .foregroundColor(Color.white.opacity(0.4))
                                .padding(6)
                        } else {
                            ForEach(Array(module.terminalLogs.enumerated()), id: \.offset) { index, line in
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
                .frame(height: 54)
                .onChange(of: module.terminalLogs.count) { _, newCount in
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
                
                TextField("Type command (e.g. status, vol 80, asmr vol 50, help)...", text: $module.cliCommandInput)
                    .font(.system(size: 8.5, design: .monospaced))
                    .textFieldStyle(.plain)
                    .foregroundColor(.white)
                    .onSubmit {
                        let cmd = module.cliCommandInput
                        module.cliCommandInput = ""
                        module.sendCommand(cmd)
                    }
                
                if !module.cliCommandInput.isEmpty {
                    Button(action: {
                        let cmd = module.cliCommandInput
                        module.cliCommandInput = ""
                        module.sendCommand(cmd)
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

// MARK: - ASMR Layer Bento Card
private struct AsmrLayerCard: View {
    let title: String
    let description: String
    let icon: String
    let isActive: Bool
    let activeColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(isActive ? activeColor.opacity(0.25) : Color.white.opacity(0.05))
                        .frame(width: 26, height: 26)
                    Image(systemName: icon)
                        .font(.system(size: 11))
                        .foregroundColor(isActive ? activeColor : Color.white.opacity(0.5))
                }
                
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text(title)
                            .font(.system(size: 9.5, weight: .bold, design: .rounded))
                            .foregroundColor(isActive ? .white : Color.white.opacity(0.85))
                        
                        Circle()
                            .fill(isActive ? activeColor : Color.white.opacity(0.2))
                            .frame(width: 4, height: 4)
                    }
                    
                    Text(isActive ? "Active · Playing" : description)
                        .font(.system(size: 7.5, weight: .regular))
                        .foregroundColor(isActive ? activeColor : DesignSystem.secondaryText)
                        .lineLimit(1)
                }
                
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isActive ? activeColor.opacity(0.12) : Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(isActive ? activeColor.opacity(0.6) : Color.white.opacity(0.08), lineWidth: isActive ? 1.0 : 0.6)
            )
        }
        .buttonStyle(.spring)
    }
}
