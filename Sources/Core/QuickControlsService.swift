import Foundation
import CoreAudio
import AudioToolbox
import Combine
import SwiftUI

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

// MARK: - Service Protocol for Dependency Injection & Deterministic Testing
public protocol QuickControlsServiceProtocol: AnyObject, Sendable {
    func getVolume() -> (volume: Float, isMuted: Bool, deviceName: String, availability: QuickControlAvailability)
    func setVolume(_ volume: Float) -> Bool
    func setMuted(_ muted: Bool) -> Bool
    func getBrightness() -> (brightness: Float, availability: QuickControlAvailability)
    func setBrightness(_ brightness: Float) -> Bool
    func getKeyboardBacklight() -> (brightness: Float, availability: QuickControlAvailability)
    func setKeyboardBacklight(_ brightness: Float) -> Bool
    
    func startObserving(onVolumeChange: @escaping @Sendable (Float, Bool, String) -> Void)
    func stopObserving()
}

// MARK: - Production System Controls Service (Core Audio HAL)
public final class SystemControlsService: QuickControlsServiceProtocol, @unchecked Sendable {
    public static let shared = SystemControlsService()
    
    private let queue = DispatchQueue(label: "com.notch.quickcontrols.coreaudio", qos: .userInteractive)
    private var volumeListenerBlock: AudioObjectPropertyListenerBlock?
    private var deviceListenerBlock: AudioObjectPropertyListenerBlock?
    private var currentObservedDevice: AudioDeviceID = 0
    private var onVolumeChangeCallback: (@Sendable (Float, Bool, String) -> Void)?
    
    public init() {}
    
    deinit {
        stopObserving()
    }
    
    // MARK: - Audio Device Discovery
    private func getDefaultOutputDevice() -> AudioDeviceID {
        var deviceID = AudioDeviceID(0)
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
        
        return (status == noErr) ? deviceID : AudioDeviceID(0)
    }
    
    private func getDeviceName(_ deviceID: AudioDeviceID) -> String {
        guard deviceID != 0 else { return "No Output Device" }
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceName: Unmanaged<CFString>?
        var propertySize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let status = AudioObjectGetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &deviceName
        )
        if status == noErr, let unmanaged = deviceName {
            let str = unmanaged.takeRetainedValue() as String
            return str
        }
        return "Output Audio"
    }
    
    // MARK: - Volume Implementation
    public func getVolume() -> (volume: Float, isMuted: Bool, deviceName: String, availability: QuickControlAvailability) {
        let deviceID = getDefaultOutputDevice()
        guard deviceID != 0 else {
            return (0.0, false, "No Audio Device", .unsupported(reason: "No active default audio output device"))
        }
        
        let name = getDeviceName(deviceID)
        
        var volumeAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        guard AudioObjectHasProperty(deviceID, &volumeAddress) else {
            return (0.0, false, name, .unsupported(reason: "Output device does not support volume control"))
        }
        
        var isSettable: DarwinBoolean = false
        _ = AudioObjectIsPropertySettable(deviceID, &volumeAddress, &isSettable)
        
        var volume: Float32 = 0.0
        var volSize = UInt32(MemoryLayout<Float32>.size)
        let status = AudioObjectGetPropertyData(deviceID, &volumeAddress, 0, nil, &volSize, &volume)
        
        guard status == noErr else {
            return (0.0, false, name, .unsupported(reason: "Failed reading volume from audio hardware"))
        }
        
        // Mute state
        var muteAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var isMuted = false
        if AudioObjectHasProperty(deviceID, &muteAddress) {
            var muteValue: UInt32 = 0
            var muteSize = UInt32(MemoryLayout<UInt32>.size)
            if AudioObjectGetPropertyData(deviceID, &muteAddress, 0, nil, &muteSize, &muteValue) == noErr {
                isMuted = (muteValue != 0)
            }
        }
        
        let availability: QuickControlAvailability = isSettable.boolValue ? .available : .readOnly(reason: "Device volume is hardware locked")
        return (max(0.0, min(1.0, volume)), isMuted, name, availability)
    }
    
    public func setVolume(_ volume: Float) -> Bool {
        let deviceID = getDefaultOutputDevice()
        guard deviceID != 0 else { return false }
        
        var volumeAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        guard AudioObjectHasProperty(deviceID, &volumeAddress) else { return false }
        
        var clampedVolume = Float32(max(0.0, min(1.0, volume)))
        let volSize = UInt32(MemoryLayout<Float32>.size)
        let status = AudioObjectSetPropertyData(deviceID, &volumeAddress, 0, nil, volSize, &clampedVolume)
        
        // Auto-unmute when volume is raised above 0
        if status == noErr && clampedVolume > 0.001 {
            _ = setMuted(false)
        }
        
        return status == noErr
    }
    
    public func setMuted(_ muted: Bool) -> Bool {
        let deviceID = getDefaultOutputDevice()
        guard deviceID != 0 else { return false }
        
        var muteAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        guard AudioObjectHasProperty(deviceID, &muteAddress) else { return false }
        
        var muteVal: UInt32 = muted ? 1 : 0
        let muteSize = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectSetPropertyData(deviceID, &muteAddress, 0, nil, muteSize, &muteVal)
        return status == noErr
    }
    
    // MARK: - Display Brightness (Public API Boundary & Honest Capability Detection)
    public func getBrightness() -> (brightness: Float, availability: QuickControlAvailability) {
        // macOS does not provide a public, documented API for built-in Apple Silicon display brightness.
        // Direct adjustment requires private DisplayServicesSetBrightness in DisplayServices.framework.
        // In strict compliance with zero-private-API requirements, report unsupported and provide System Settings route.
        return (1.0, .unsupported(reason: "System Managed (Adjust via Control Center or Displays Settings)"))
    }
    
    public func setBrightness(_ brightness: Float) -> Bool {
        // Honest refusal to invoke private DisplayServices symbols
        return false
    }
    
    // MARK: - Keyboard Backlight (Public API Boundary & Honest Capability Detection)
    public func getKeyboardBacklight() -> (brightness: Float, availability: QuickControlAvailability) {
        // macOS does not provide a public, documented API for keyboard backlight brightness.
        // Direct adjustment requires private CoreBrightness.framework (KeyboardBrightnessClient).
        // In strict compliance with zero-private-API requirements, report unsupported and provide Keyboard Settings route.
        return (0.0, .unsupported(reason: "Hardware Managed (Use Keyboard Brightness Keys or Control Center)"))
    }
    
    public func setKeyboardBacklight(_ brightness: Float) -> Bool {
        // Honest refusal to invoke private CoreBrightness symbols
        return false
    }
    
    // MARK: - Core Audio Observers
    public func startObserving(onVolumeChange: @escaping @Sendable (Float, Bool, String) -> Void) {
        stopObserving()
        self.onVolumeChangeCallback = onVolumeChange
        
        let deviceID = getDefaultOutputDevice()
        self.currentObservedDevice = deviceID
        
        // 1. Observe default output device changes (e.g. AirPods connected/disconnected)
        var defaultDeviceAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let devBlock: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            guard let self = self else { return }
            self.queue.async {
                let newDevice = self.getDefaultOutputDevice()
                self.rebindVolumeListener(to: newDevice)
                let info = self.getVolume()
                self.onVolumeChangeCallback?(info.volume, info.isMuted, info.deviceName)
            }
        }
        self.deviceListenerBlock = devBlock
        _ = AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &defaultDeviceAddress,
            self.queue,
            devBlock
        )
        
        // 2. Observe volume changes on the current device
        bindVolumeListener(to: deviceID)
    }
    
    private func bindVolumeListener(to deviceID: AudioDeviceID) {
        guard deviceID != 0 else { return }
        
        var volumeAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let volBlock: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            guard let self = self else { return }
            let info = self.getVolume()
            self.onVolumeChangeCallback?(info.volume, info.isMuted, info.deviceName)
        }
        self.volumeListenerBlock = volBlock
        
        _ = AudioObjectAddPropertyListenerBlock(
            deviceID,
            &volumeAddress,
            self.queue,
            volBlock
        )
    }
    
    private func rebindVolumeListener(to newDeviceID: AudioDeviceID) {
        if currentObservedDevice != 0, let oldBlock = volumeListenerBlock {
            var oldAddress = AudioObjectPropertyAddress(
                mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
                mScope: kAudioObjectPropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            _ = AudioObjectRemovePropertyListenerBlock(currentObservedDevice, &oldAddress, queue, oldBlock)
        }
        self.currentObservedDevice = newDeviceID
        bindVolumeListener(to: newDeviceID)
    }
    
    public func stopObserving() {
        if let devBlock = deviceListenerBlock {
            var defaultDeviceAddress = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            _ = AudioObjectRemovePropertyListenerBlock(
                AudioObjectID(kAudioObjectSystemObject),
                &defaultDeviceAddress,
                queue,
                devBlock
            )
            self.deviceListenerBlock = nil
        }
        
        if currentObservedDevice != 0, let volBlock = volumeListenerBlock {
            var volumeAddress = AudioObjectPropertyAddress(
                mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
                mScope: kAudioObjectPropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            _ = AudioObjectRemovePropertyListenerBlock(
                currentObservedDevice,
                &volumeAddress,
                queue,
                volBlock
            )
            self.volumeListenerBlock = nil
            self.currentObservedDevice = 0
        }
        
        self.onVolumeChangeCallback = nil
    }
}

// MARK: - Mock Controls Service for Deterministic Regression Tests
public final class MockQuickControlsService: QuickControlsServiceProtocol, @unchecked Sendable {
    public var mockVolume: Float = 0.50
    public var mockIsMuted: Bool = false
    public var mockDeviceName: String = "Mock Studio Display"
    public var mockVolumeAvailability: QuickControlAvailability = .available
    
    public var mockBrightness: Float = 0.80
    public var mockBrightnessAvailability: QuickControlAvailability = .available
    
    public var mockKeyboardBrightness: Float = 0.40
    public var mockKeyboardBrightnessAvailability: QuickControlAvailability = .available
    
    public var onVolumeChange: (@Sendable (Float, Bool, String) -> Void)?
    
    public init() {}
    
    public func getVolume() -> (volume: Float, isMuted: Bool, deviceName: String, availability: QuickControlAvailability) {
        (mockVolume, mockIsMuted, mockDeviceName, mockVolumeAvailability)
    }
    
    public func setVolume(_ volume: Float) -> Bool {
        guard mockVolumeAvailability.isUsable else { return false }
        mockVolume = max(0.0, min(1.0, volume))
        if mockVolume > 0.001 {
            mockIsMuted = false
        }
        onVolumeChange?(mockVolume, mockIsMuted, mockDeviceName)
        return true
    }
    
    public func setMuted(_ muted: Bool) -> Bool {
        guard mockVolumeAvailability.isUsable else { return false }
        mockIsMuted = muted
        onVolumeChange?(mockVolume, mockIsMuted, mockDeviceName)
        return true
    }
    
    public func getBrightness() -> (brightness: Float, availability: QuickControlAvailability) {
        (mockBrightness, mockBrightnessAvailability)
    }
    
    public func setBrightness(_ brightness: Float) -> Bool {
        guard mockBrightnessAvailability.isUsable else { return false }
        mockBrightness = max(0.0, min(1.0, brightness))
        return true
    }
    
    public func getKeyboardBacklight() -> (brightness: Float, availability: QuickControlAvailability) {
        (mockKeyboardBrightness, mockKeyboardBrightnessAvailability)
    }
    
    public func setKeyboardBacklight(_ brightness: Float) -> Bool {
        guard mockKeyboardBrightnessAvailability.isUsable else { return false }
        mockKeyboardBrightness = max(0.0, min(1.0, brightness))
        return true
    }
    
    public func startObserving(onVolumeChange: @escaping @Sendable (Float, Bool, String) -> Void) {
        self.onVolumeChange = onVolumeChange
    }
    
    public func stopObserving() {
        self.onVolumeChange = nil
    }
}

// MARK: - Quick Controls State Machine
public enum QuickControlsState: String, Equatable, Sendable {
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

// MARK: - Observable Quick Controls Manager
@MainActor
public final class QuickControlsManager: ObservableObject {
    public static let shared = QuickControlsManager()
    
    private var service: QuickControlsServiceProtocol
    
    @Published public var state: QuickControlsState = .closed
    @Published public var volume: Double = 0.50
    @Published public var isMuted: Bool = false
    @Published public var activeAudioDeviceName: String = "Speakers"
    @Published public var volumeAvailability: QuickControlAvailability = .available
    
    @Published public var brightness: Double = 0.80
    @Published public var brightnessAvailability: QuickControlAvailability = .unsupported(reason: "System Managed")
    
    @Published public var keyboardBrightness: Double = 0.40
    @Published public var keyboardBrightnessAvailability: QuickControlAvailability = .unsupported(reason: "Hardware Managed")
    
    @Published public var isInteractingWithSlider: Bool = false
    
    private var hoverGraceTask: Task<Void, Never>?
    
    public init(service: QuickControlsServiceProtocol = SystemControlsService.shared) {
        self.service = service
        refreshAll()
        startServiceObserving()
    }
    
    public func setServiceForTesting(_ testService: QuickControlsServiceProtocol) {
        self.service.stopObserving()
        self.service = testService
        refreshAll()
        startServiceObserving()
    }
    
    public func restoreProductionService() {
        self.service.stopObserving()
        self.service = SystemControlsService.shared
        refreshAll()
        startServiceObserving()
    }
    
    public func refreshAll() {
        let volInfo = service.getVolume()
        self.volume = Double(volInfo.volume)
        self.isMuted = volInfo.isMuted
        self.activeAudioDeviceName = volInfo.deviceName
        self.volumeAvailability = volInfo.availability
        
        let brightInfo = service.getBrightness()
        self.brightness = Double(brightInfo.brightness)
        self.brightnessAvailability = brightInfo.availability
        
        let kbdInfo = service.getKeyboardBacklight()
        self.keyboardBrightness = Double(kbdInfo.brightness)
        self.keyboardBrightnessAvailability = kbdInfo.availability
    }
    
    private func startServiceObserving() {
        service.startObserving { [weak self] newVol, newMute, newDevice in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                // Only update from hardware if user is NOT currently dragging the slider
                if !self.isInteractingWithSlider {
                    self.volume = Double(newVol)
                    self.isMuted = newMute
                    self.activeAudioDeviceName = newDevice
                }
            }
        }
    }
    
    // MARK: - Actions
    public func setVolumeValue(_ newValue: Double) {
        let clamped = max(0.0, min(1.0, newValue))
        self.volume = clamped
        if clamped > 0.001 && isMuted {
            self.isMuted = false
        }
        _ = service.setVolume(Float(clamped))
    }
    
    public func toggleMute() {
        let target = !isMuted
        self.isMuted = target
        _ = service.setMuted(target)
    }
    
    public func setBrightnessValue(_ newValue: Double) {
        let clamped = max(0.0, min(1.0, newValue))
        self.brightness = clamped
        _ = service.setBrightness(Float(clamped))
    }
    
    public func setKeyboardBrightnessValue(_ newValue: Double) {
        let clamped = max(0.0, min(1.0, newValue))
        self.keyboardBrightness = clamped
        _ = service.setKeyboardBacklight(Float(clamped))
    }
    
    // MARK: - State Machine Transitions
    public func onDisclosureHoverEntered() {
        hoverGraceTask?.cancel()
        hoverGraceTask = nil
        
        let isPinned = SettingsStore.shared.quickControlsPinned
        if isPinned {
            state = .pinned
        } else if state == .closed {
            state = .hoverPreview
        }
    }
    
    public func onDisclosureOrPanelHoverExited() {
        // If pinned or actively dragging a slider, NEVER collapse!
        guard !SettingsStore.shared.quickControlsPinned else { return }
        guard !isInteractingWithSlider else { return }
        
        // Grace period (350ms) to allow moving pointer comfortably between row and panel
        hoverGraceTask?.cancel()
        hoverGraceTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            guard !SettingsStore.shared.quickControlsPinned else { return }
            guard !self.isInteractingWithSlider else { return }
            self.state = .closed
        }
    }
    
    public func togglePin() {
        let store = SettingsStore.shared
        store.quickControlsPinned.toggle()
        if store.quickControlsPinned {
            state = .pinned
            FeedbackManager.playPin()
        } else {
            state = .hoverPreview
            FeedbackManager.playClick()
        }
    }
    
    public func onSliderDragStarted() {
        hoverGraceTask?.cancel()
        hoverGraceTask = nil
        self.isInteractingWithSlider = true
        self.state = .interacting
    }
    
    public func onSliderDragEnded() {
        self.isInteractingWithSlider = false
        if SettingsStore.shared.quickControlsPinned {
            self.state = .pinned
        } else {
            self.state = .hoverPreview
        }
    }
    
    public func openSystemDisplaysSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Displays-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }
    
    public func openSystemKeyboardSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }
}
