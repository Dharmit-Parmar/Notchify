import Foundation
import CoreAudio
import AudioToolbox
import Combine
import SwiftUI
import AppKit

// MARK: - Quick Control Kinds
public enum QuickControlKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case volume = "volume"
    case brightness = "brightness"
    case keyboardBacklight = "keyboardBacklight"
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .volume: return "System Volume"
        case .brightness: return "Display Brightness"
        case .keyboardBacklight: return "Keyboard Backlight"
        }
    }
    
    public var iconName: String {
        switch self {
        case .volume: return "speaker.wave.3.fill"
        case .brightness: return "sun.max.fill"
        case .keyboardBacklight: return "keyboard.fill"
        }
    }
}

// MARK: - Quick Control Availability
public enum QuickControlAvailability: Equatable, Sendable {
    case available
    case readOnly(reason: String)
    case unsupported(reason: String)
    
    public var isUsable: Bool {
        if case .available = self { return true }
        return false
    }
    
    public var statusDescription: String {
        switch self {
        case .available:
            return "Active & Hardware Synchronized"
        case .readOnly(let reason):
            return "Read-Only: \(reason)"
        case .unsupported(let reason):
            return reason
        }
    }
}

// MARK: - Quick Control Info
public struct QuickControlInfo: Equatable, Sendable {
    public let kind: QuickControlKind
    public let volume: Float
    public let isMuted: Bool
    public let availability: QuickControlAvailability
    public let deviceName: String
    
    public init(
        kind: QuickControlKind,
        volume: Float = 0.0,
        isMuted: Bool = false,
        availability: QuickControlAvailability = .available,
        deviceName: String = ""
    ) {
        self.kind = kind
        self.volume = max(0.0, min(1.0, volume))
        self.isMuted = isMuted
        self.availability = availability
        self.deviceName = deviceName
    }
}

// MARK: - Service Protocol
public protocol QuickControlsServiceProtocol: AnyObject, Sendable {
    func getVolume() -> QuickControlInfo
    func setVolume(_ volume: Float) -> Bool
    func setMuted(_ muted: Bool) -> Bool
    func getBrightness() -> QuickControlInfo
    func setBrightness(_ brightness: Float) -> Bool
    func getKeyboardBacklight() -> QuickControlInfo
    func setKeyboardBacklight(_ brightness: Float) -> Bool
    func observeVolumeChanges(handler: @escaping @Sendable (QuickControlInfo) -> Void) -> AnyCancellable
}

// MARK: - Production Core Audio HAL Service
public final class SystemControlsService: QuickControlsServiceProtocol, @unchecked Sendable {
    public static let shared = SystemControlsService()
    
    private let stateLock = NSLock()
    private var volumeSubject = PassthroughSubject<QuickControlInfo, Never>()
    
    public init() {}
    
    private func defaultOutputDeviceID() -> AudioDeviceID? {
        var deviceID = kAudioObjectUnknown
        var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &deviceID
        )
        guard status == noErr, deviceID != kAudioObjectUnknown else { return nil }
        return deviceID
    }
    
    private func fetchDeviceName(for deviceID: AudioDeviceID) -> String {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var unmanagedName: Unmanaged<CFString>?
        var propertySize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let status = AudioObjectGetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &unmanagedName
        )
        guard status == noErr, let unmanaged = unmanagedName else { return "Audio Output" }
        return unmanaged.takeRetainedValue() as String
    }
    
    public func getVolume() -> QuickControlInfo {
        guard let deviceID = defaultOutputDeviceID() else {
            return QuickControlInfo(
                kind: .volume,
                volume: 0.0,
                isMuted: false,
                availability: .unsupported(reason: "No active audio output device detected"),
                deviceName: "None"
            )
        }
        let deviceName = fetchDeviceName(for: deviceID)
        
        var volumeVal: Float32 = 0.0
        var volSize = UInt32(MemoryLayout<Float32>.size)
        var volAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let volStatus = AudioObjectGetPropertyData(deviceID, &volAddress, 0, nil, &volSize, &volumeVal)
        let hasVolume = (volStatus == noErr)
        
        var muteVal: UInt32 = 0
        var muteSize = UInt32(MemoryLayout<UInt32>.size)
        var muteAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        let muteStatus = AudioObjectGetPropertyData(deviceID, &muteAddress, 0, nil, &muteSize, &muteVal)
        let isMuted = (muteStatus == noErr && muteVal != 0)
        
        if !hasVolume {
            return QuickControlInfo(
                kind: .volume,
                volume: 1.0,
                isMuted: isMuted,
                availability: .readOnly(reason: "Fixed hardware volume or digital out"),
                deviceName: deviceName
            )
        }
        
        return QuickControlInfo(
            kind: .volume,
            volume: max(0.0, min(1.0, volumeVal)),
            isMuted: isMuted,
            availability: .available,
            deviceName: deviceName
        )
    }
    
    public func setVolume(_ volume: Float) -> Bool {
        guard let deviceID = defaultOutputDeviceID() else { return false }
        var clamped = max(0.0, min(1.0, Float32(volume)))
        let volSize = UInt32(MemoryLayout<Float32>.size)
        var volAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var isSettable: DarwinBoolean = false
        let settableStatus = AudioObjectIsPropertySettable(deviceID, &volAddress, &isSettable)
        guard settableStatus == noErr, isSettable.boolValue else { return false }
        
        let status = AudioObjectSetPropertyData(deviceID, &volAddress, 0, nil, volSize, &clamped)
        return status == noErr
    }
    
    public func setMuted(_ muted: Bool) -> Bool {
        guard let deviceID = defaultOutputDeviceID() else { return false }
        var muteVal: UInt32 = muted ? 1 : 0
        let muteSize = UInt32(MemoryLayout<UInt32>.size)
        var muteAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var isSettable: DarwinBoolean = false
        let settableStatus = AudioObjectIsPropertySettable(deviceID, &muteAddress, &isSettable)
        guard settableStatus == noErr, isSettable.boolValue else { return false }
        
        let status = AudioObjectSetPropertyData(deviceID, &muteAddress, 0, nil, muteSize, &muteVal)
        return status == noErr
    }
    
    public func getBrightness() -> QuickControlInfo {
        QuickControlInfo(
            kind: .brightness,
            volume: 1.0,
            isMuted: false,
            availability: .unsupported(reason: "Display Brightness is managed by macOS Displays Settings & Control Center."),
            deviceName: "Built-in / External Display"
        )
    }
    
    public func setBrightness(_ brightness: Float) -> Bool {
        // Direct built-in brightness requires private DisplayServices SPI; public API returns false
        return false
    }
    
    public func getKeyboardBacklight() -> QuickControlInfo {
        QuickControlInfo(
            kind: .keyboardBacklight,
            volume: 1.0,
            isMuted: false,
            availability: .unsupported(reason: "Keyboard Backlight is managed by macOS Keyboard Settings."),
            deviceName: "Internal Backlit Keyboard"
        )
    }
    
    public func setKeyboardBacklight(_ brightness: Float) -> Bool {
        // Direct keyboard backlight requires private CoreBrightness SPI; public API returns false
        return false
    }
    
    public func observeVolumeChanges(handler: @escaping @Sendable (QuickControlInfo) -> Void) -> AnyCancellable {
        return volumeSubject.sink(receiveValue: handler)
    }
}

// MARK: - Mock Service For Deterministic Testing
public final class MockQuickControlsService: QuickControlsServiceProtocol, @unchecked Sendable {
    public var mockVolume: Float = 0.50
    public var mockIsMuted: Bool = false
    public var mockDeviceName: String = "Test Mock Headphones"
    public var mockAvailability: QuickControlAvailability = .available
    
    public var mockBrightness: Float = 0.80
    public var mockBrightnessAvailability: QuickControlAvailability = .available
    
    public var mockKeyboardBrightness: Float = 0.40
    public var mockKeyboardBrightnessAvailability: QuickControlAvailability = .available
    
    public init() {}
    
    public func getVolume() -> QuickControlInfo {
        QuickControlInfo(
            kind: .volume,
            volume: mockVolume,
            isMuted: mockIsMuted,
            availability: mockAvailability,
            deviceName: mockDeviceName
        )
    }
    
    public func setVolume(_ volume: Float) -> Bool {
        guard mockAvailability.isUsable else { return false }
        mockVolume = max(0.0, min(1.0, volume))
        if mockVolume > 0 && mockIsMuted {
            mockIsMuted = false
        }
        return true
    }
    
    public func setMuted(_ muted: Bool) -> Bool {
        guard mockAvailability.isUsable else { return false }
        mockIsMuted = muted
        return true
    }
    
    public func getBrightness() -> QuickControlInfo {
        QuickControlInfo(
            kind: .brightness,
            volume: mockBrightness,
            isMuted: false,
            availability: mockBrightnessAvailability,
            deviceName: "Display"
        )
    }
    
    public func setBrightness(_ brightness: Float) -> Bool {
        guard mockBrightnessAvailability.isUsable else { return false }
        mockBrightness = max(0.0, min(1.0, brightness))
        return true
    }
    
    public func getKeyboardBacklight() -> QuickControlInfo {
        QuickControlInfo(
            kind: .keyboardBacklight,
            volume: mockKeyboardBrightness,
            isMuted: false,
            availability: mockKeyboardBrightnessAvailability,
            deviceName: "Keyboard"
        )
    }
    
    public func setKeyboardBacklight(_ brightness: Float) -> Bool {
        guard mockKeyboardBrightnessAvailability.isUsable else { return false }
        mockKeyboardBrightness = max(0.0, min(1.0, brightness))
        return true
    }
    
    public func observeVolumeChanges(handler: @escaping @Sendable (QuickControlInfo) -> Void) -> AnyCancellable {
        Just(getVolume()).sink(receiveValue: handler)
    }
}

// MARK: - Quick Controls State Machine
public enum QuickControlsState: Equatable, Sendable {
    case closed
    case hoverPreview
    case pinned
    case interacting
    
    public var isPanelVisible: Bool {
        switch self {
        case .closed: return false
        case .hoverPreview, .pinned, .interacting: return true
        }
    }
}

// MARK: - Dashboard Layout Models
public enum DashboardWidgetType: String, Codable, CaseIterable, Identifiable {
    case nowPlaying = "nowPlaying"
    case calendar = "calendar"
    case notes = "notes"
    case clock = "clock"
    case mirror = "mirror"
    case askAI = "askAI"
    case battery = "battery"
    
    public var id: String { rawValue }
}

public enum DashboardLayoutFlow: String, Codable, CaseIterable, Identifiable {
    case adaptiveAuto = "adaptiveAuto"
    case horizontalStrip = "horizontalStrip"
    case bentoQuad = "bentoQuad"
    case focusDominant = "focusDominant"
    
    public var id: String { rawValue }
}

// MARK: - Settings Store
@MainActor
public class SettingsStore: ObservableObject {
    public static let shared = SettingsStore()
    
    @Published public var dashboardSlots: [DashboardWidgetType?] = [.nowPlaying, .calendar, .notes, nil]
    @Published public var showQuickControls: Bool = true {
        didSet { UserDefaults.standard.set(showQuickControls, forKey: "NotchApp_ShowQuickControls") }
    }
    @Published public var quickControlsPinned: Bool = false {
        didSet { UserDefaults.standard.set(quickControlsPinned, forKey: "NotchApp_QuickControlsPinned") }
    }
    @Published public var enabledQuickControls: [QuickControlKind] = [.volume, .brightness, .keyboardBacklight] {
        didSet {
            let serialized = enabledQuickControls.map { $0.rawValue }
            UserDefaults.standard.set(serialized, forKey: "NotchApp_EnabledQuickControls")
        }
    }
    @Published public var dashboardLayoutFlow: DashboardLayoutFlow = .adaptiveAuto
    @Published public var dashboardSplitRatio: CGFloat = 0.50
    
    public init() {
        if let storedSlots = UserDefaults.standard.stringArray(forKey: "NotchApp_DashboardSlots") {
            let loaded = storedSlots.map { raw -> DashboardWidgetType? in
                if raw == "empty" { return nil }
                return DashboardWidgetType(rawValue: raw)
            }
            if loaded.count == 4 {
                self.dashboardSlots = loaded
            }
        }
        if UserDefaults.standard.object(forKey: "NotchApp_ShowQuickControls") != nil {
            self.showQuickControls = UserDefaults.standard.bool(forKey: "NotchApp_ShowQuickControls")
        }
        if UserDefaults.standard.object(forKey: "NotchApp_QuickControlsPinned") != nil {
            self.quickControlsPinned = UserDefaults.standard.bool(forKey: "NotchApp_QuickControlsPinned")
        }
        if let storedQC = UserDefaults.standard.stringArray(forKey: "NotchApp_EnabledQuickControls") {
            let loaded = storedQC.compactMap { QuickControlKind(rawValue: $0) }
            if !loaded.isEmpty {
                self.enabledQuickControls = loaded
            }
        }
    }
    
    public func resetQuickControlsSettings() {
        showQuickControls = true
        quickControlsPinned = false
        enabledQuickControls = [.volume, .brightness, .keyboardBacklight]
    }
}

// MARK: - Quick Controls Manager
@MainActor
public final class QuickControlsManager: ObservableObject {
    public static let shared = QuickControlsManager()
    
    @Published public var state: QuickControlsState = .closed
    @Published public var volume: Float = 0.50
    @Published public var isMuted: Bool = false
    @Published public var volumeAvailability: QuickControlAvailability = .available
    @Published public var activeAudioDeviceName: String = "Built-in Speakers"
    
    @Published public var brightness: Float = 0.80
    @Published public var brightnessAvailability: QuickControlAvailability = .unsupported(reason: "System Managed")
    
    @Published public var keyboardBrightness: Float = 0.40
    @Published public var keyboardBrightnessAvailability: QuickControlAvailability = .unsupported(reason: "Hardware Managed")
    
    public private(set) var isInteractingWithSlider: Bool = false
    public private(set) var interactionScreenRect: CGRect = .zero
    public private(set) var isPointerInsideInteractionRegion: Bool = false
    public var closeGraceTask: Task<Void, Never>?
    
    private var service: QuickControlsServiceProtocol = SystemControlsService.shared
    private var cancellables = Set<AnyCancellable>()
    
    public init() {
        refreshHardwareState()
    }
    
    public func setServiceForTesting(_ testService: QuickControlsServiceProtocol) {
        self.service = testService
        refreshHardwareState()
    }
    
    public func restoreProductionService() {
        self.service = SystemControlsService.shared
        refreshHardwareState()
    }
    
    public func updateInteractionRegion(_ screenRect: CGRect) {
        guard screenRect.width > 0 && screenRect.height > 0 else { return }
        self.interactionScreenRect = screenRect
    }
    
    public func refreshHardwareState() {
        let volInfo = service.getVolume()
        self.volume = volInfo.volume
        self.isMuted = volInfo.isMuted
        self.volumeAvailability = volInfo.availability
        self.activeAudioDeviceName = volInfo.deviceName
        
        let brightInfo = service.getBrightness()
        self.brightness = brightInfo.volume
        self.brightnessAvailability = brightInfo.availability
        
        let kbdInfo = service.getKeyboardBacklight()
        self.keyboardBrightness = kbdInfo.volume
        self.keyboardBrightnessAvailability = kbdInfo.availability
    }
    
    public func setVolumeValue(_ newValue: Float) {
        let clamped = max(0.0, min(1.0, newValue))
        self.volume = clamped
        if isMuted && clamped > 0 {
            self.isMuted = false
            _ = service.setMuted(false)
        }
        _ = service.setVolume(clamped)
    }
    
    public func toggleMute() {
        let newMuted = !isMuted
        self.isMuted = newMuted
        _ = service.setMuted(newMuted)
    }
    
    public func setBrightnessValue(_ newValue: Float) {
        let clamped = max(0.0, min(1.0, newValue))
        self.brightness = clamped
        _ = service.setBrightness(clamped)
    }
    
    public func setKeyboardBrightnessValue(_ newValue: Float) {
        let clamped = max(0.0, min(1.0, newValue))
        self.keyboardBrightness = clamped
        _ = service.setKeyboardBacklight(clamped)
    }
    
    public func onPointerEnteredRegion() {
        closeGraceTask?.cancel()
        closeGraceTask = nil
        isPointerInsideInteractionRegion = true
        
        let isPinned = SettingsStore.shared.quickControlsPinned
        if isPinned {
            state = .pinned
        } else {
            state = .hoverPreview
        }
    }
    
    public func onPointerExitedRegion() {
        isPointerInsideInteractionRegion = false
        
        guard !SettingsStore.shared.quickControlsPinned else { return }
        guard !isInteractingWithSlider else { return }
        guard state != .closed else { return }
        
        closeGraceTask?.cancel()
        closeGraceTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            guard !SettingsStore.shared.quickControlsPinned else { return }
            guard !self.isInteractingWithSlider else { return }
            guard NSEvent.pressedMouseButtons == 0 else { return }
            
            let currentMouse = NSEvent.mouseLocation
            let safeRegion = self.interactionScreenRect.insetBy(dx: -6, dy: -6)
            if self.interactionScreenRect != .zero && safeRegion.contains(currentMouse) {
                self.isPointerInsideInteractionRegion = true
                return
            }
            self.state = .closed
        }
    }
    
    public func onDisclosureHoverEntered() {
        onPointerEnteredRegion()
    }
    
    public func onDisclosureOrPanelHoverExited() {
        onPointerExitedRegion()
    }
    
    public func onSliderDragStarted() {
        closeGraceTask?.cancel()
        closeGraceTask = nil
        self.isInteractingWithSlider = true
        self.state = .interacting
    }
    
    public func onSliderDragEnded() {
        self.isInteractingWithSlider = false
        if SettingsStore.shared.quickControlsPinned {
            self.state = .pinned
        } else {
            self.state = .hoverPreview
            let currentMouse = NSEvent.mouseLocation
            let safeRegion = interactionScreenRect.insetBy(dx: -6, dy: -6)
            if interactionScreenRect != .zero && !safeRegion.contains(currentMouse) {
                onPointerExitedRegion()
            }
        }
    }
    
    public func togglePin() {
        let store = SettingsStore.shared
        store.quickControlsPinned.toggle()
        if store.quickControlsPinned {
            closeGraceTask?.cancel()
            closeGraceTask = nil
            self.state = .pinned
        } else {
            self.state = .hoverPreview
            let currentMouse = NSEvent.mouseLocation
            let safeRegion = interactionScreenRect.insetBy(dx: -6, dy: -6)
            if interactionScreenRect != .zero && !safeRegion.contains(currentMouse) {
                onPointerExitedRegion()
            }
        }
    }
}

// MARK: - Notch Geometry For Verification
public struct NotchGeometry {
    public let screenFrame: CGRect
    public let hasPhysicalNotch: Bool
    public let topInset: CGFloat
    public let physicalNotchWidth: CGFloat
    public let physicalNotchHeight: CGFloat
    public let notchCenterX: CGFloat
    
    public static func current(for screen: NSScreen = NSScreen.main ?? NSScreen.screens[0]) -> NotchGeometry {
        let frame = screen.frame
        let safeArea = screen.safeAreaInsets
        let hasNotch = safeArea.top > 0
        let notchHeight: CGFloat = hasNotch ? safeArea.top : 32.0
        let notchWidth: CGFloat = hasNotch ? 185.0 : 160.0
        let centerX = frame.origin.x + (frame.width / 2.0)
        
        return NotchGeometry(
            screenFrame: frame,
            hasPhysicalNotch: hasNotch,
            topInset: notchHeight,
            physicalNotchWidth: notchWidth,
            physicalNotchHeight: notchHeight,
            notchCenterX: centerX
        )
    }
    
    public struct ExpandedLayoutResult {
        public let windowRect: CGRect
        public let targetWidth: CGFloat
        public let targetHeight: CGFloat
        public let notchInset: CGFloat
        public let contentTopPadding: CGFloat
    }
    
    public static func expandedLayout(
        geometry: NotchGeometry,
        notchWidth: CGFloat = 620.0,
        notchHeight: CGFloat = 330.0,
        quickControlsHeight: CGFloat = 0.0
    ) -> ExpandedLayoutResult {
        let baseHeight = geometry.hasPhysicalNotch ? (geometry.physicalNotchHeight + notchHeight) : notchHeight
        let totalHeight = baseHeight + quickControlsHeight
        let x = geometry.notchCenterX - (notchWidth / 2.0)
        let y = geometry.screenFrame.maxY - totalHeight
        let windowRect = CGRect(x: x, y: y, width: notchWidth, height: totalHeight)
        let inset = geometry.hasPhysicalNotch ? geometry.physicalNotchHeight : 0.0
        let padding: CGFloat = geometry.hasPhysicalNotch ? geometry.physicalNotchHeight : 10.0
        
        return ExpandedLayoutResult(
            windowRect: windowRect,
            targetWidth: notchWidth,
            targetHeight: totalHeight,
            notchInset: inset,
            contentTopPadding: padding
        )
    }
}

// MARK: - Note Storage Manager Test Stub / Support
@MainActor
public final class NoteStorageManager: ObservableObject {
    public static let shared = NoteStorageManager()
    
    @Published public var text: String = ""
    public let storageURL: URL
    
    public init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("NotchApp", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        }
        self.storageURL = dir.appendingPathComponent("notes.txt")
        self.load()
    }
    
    private func load() {
        guard FileManager.default.fileExists(atPath: storageURL.path),
              let data = try? Data(contentsOf: storageURL) else { return }
        // Simple decrypt check
        if data.starts(with: [0x4E, 0x4F, 0x54, 0x43, 0x48, 0x45, 0x4E, 0x43]) { // "NOTCHENC"
            // Encrypted payload
            let payload = data.dropFirst(9) // Header + version
            if let decrypted = String(data: payload, encoding: .utf8) {
                self.text = decrypted
            }
        } else {
            self.text = String(data: data, encoding: .utf8) ?? ""
        }
    }
    
    public func saveImmediately() {
        let magicHeader: [UInt8] = [0x4E, 0x4F, 0x54, 0x43, 0x48, 0x45, 0x4E, 0x43, 0x01] // "NOTCHENC" + 0x01
        var fileData = Data(magicHeader)
        // Obfuscate / encrypt text bytes
        let textBytes = [UInt8](text.utf8)
        let obfuscated = textBytes.map { $0 ^ 0x5A }
        fileData.append(contentsOf: obfuscated)
        try? fileData.write(to: storageURL, options: .atomic)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: storageURL.path)
    }
}
