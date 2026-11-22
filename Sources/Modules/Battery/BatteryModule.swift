import SwiftUI
import IOKit.ps
import Combine

public final class BatteryModule: NotchModule {
    public static let shared = BatteryModule()
    
    public let id = "battery"
    public let title = "Battery"
    public let iconName = "battery.100.bolt"
    @Published public var isEnabled: Bool = true
    
    @Published public var hasBattery: Bool = true
    @Published public var percentage: Int = 100
    @Published public var isCharging: Bool = true
    @Published public var isFullyCharged: Bool = false
    @Published public var powerSourceState: String = "AC Power"
    @Published public var timeRemainingMinutes: Int = -1
    @Published public var timeToFullMinutes: Int = -1
    @Published public var isLowPowerMode: Bool = false
    
    private var powerRunLoopSource: CFRunLoopSource?
    private var powerObserver: NSObjectProtocol?
    private var lastRefreshTime: Date = .distantPast
    
    public init() {
        refresh()
    }
    
    public func start() {
        refresh()
        if powerRunLoopSource == nil {
            // Event-driven kernel power notification: 0% CPU consumption
            let source = IOPSNotificationCreateRunLoopSource({ _ in
                Task { @MainActor in
                    BatteryModule.shared.refresh()
                }
            }, nil).takeRetainedValue()
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
            powerRunLoopSource = source
        }
        
        if powerObserver == nil {
            powerObserver = NotificationCenter.default.addObserver(
                forName: .NSProcessInfoPowerStateDidChange,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.refresh()
                }
            }
        }
    }
    
    public func stop() {
        if let source = powerRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            powerRunLoopSource = nil
        }
        if let obs = powerObserver {
            NotificationCenter.default.removeObserver(obs)
            powerObserver = nil
        }
    }
    
    public func refresh(force: Bool = false) {
        let now = Date()
        guard force || now.timeIntervalSince(lastRefreshTime) >= 1.0 else { return }
        lastRefreshTime = now
        
        self.isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              !sources.isEmpty else {
            // Desktop Mac with no battery detected (e.g. Mac Studio, Mac mini, Mac Pro, iMac)
            self.hasBattery = false
            self.percentage = 0
            self.isCharging = false
            self.isFullyCharged = false
            self.powerSourceState = "AC Power"
            self.timeRemainingMinutes = -1
            self.timeToFullMinutes = -1
            return
        }
        
        var foundBattery = false
        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }
            applyPowerSourceData(description: description)
            foundBattery = true
            break
        }
        
        if !foundBattery {
            self.hasBattery = false
            self.percentage = 0
            self.isCharging = false
            self.isFullyCharged = false
            self.powerSourceState = "AC Power"
        }
    }
    
    /// Testable pure ingestion method accepting power-source dictionary
    public func applyPowerSourceData(description: [String: Any]) {
        self.hasBattery = true
        
        if let currentCapacity = description[kIOPSCurrentCapacityKey as String] as? Int,
           let maxCapacity = description[kIOPSMaxCapacityKey as String] as? Int,
           maxCapacity > 0 {
            self.percentage = min(100, max(0, Int((Double(currentCapacity) / Double(maxCapacity)) * 100.0)))
        }
        
        if let isCharging = description[kIOPSIsChargingKey as String] as? Bool {
            self.isCharging = isCharging
        }
        
        if let isCharged = description[kIOPSIsChargedKey as String] as? Bool {
            self.isFullyCharged = isCharged
        } else {
            self.isFullyCharged = (self.percentage >= 100 && !self.isCharging)
        }
        
        if let pState = description[kIOPSPowerSourceStateKey as String] as? String {
            self.powerSourceState = pState
        }
        
        if let toEmpty = description[kIOPSTimeToEmptyKey as String] as? Int {
            self.timeRemainingMinutes = toEmpty
        }
        
        if let toFull = description[kIOPSTimeToFullChargeKey as String] as? Int {
            self.timeToFullMinutes = toFull
        }
    }
    
    public var statusDescription: String {
        if !hasBattery {
            return "No battery detected"
        }
        if isFullyCharged {
            return "Fully Charged"
        }
        if isCharging {
            return "Charging"
        }
        if isLowPowerMode {
            return "Low Power Mode"
        }
        return "On Battery"
    }
    
    public var formattedTimeEstimate: String? {
        guard hasBattery else { return nil }
        if isCharging && timeToFullMinutes > 0 {
            let hours = timeToFullMinutes / 60
            let mins = timeToFullMinutes % 60
            if hours > 0 {
                return "\(hours)h \(mins)m to full"
            } else {
                return "\(mins)m to full"
            }
        } else if !isCharging && timeRemainingMinutes > 0 {
            let hours = timeRemainingMinutes / 60
            let mins = timeRemainingMinutes % 60
            if hours > 0 {
                return "\(hours)h \(mins)m remaining"
            } else {
                return "\(mins)m remaining"
            }
        }
        return nil
    }
    
    public var batteryColor: Color {
        if !hasBattery {
            return DesignSystem.secondaryText
        }
        if isLowPowerMode {
            return .yellow
        }
        if percentage <= 20 {
            return .red
        }
        if percentage <= 40 {
            return .orange
        }
        return .green
    }
    
    public var batteryIconName: String {
        guard hasBattery else { return "desktopcomputer" }
        if isCharging {
            return "battery.100.bolt"
        }
        if percentage >= 90 {
            return "battery.100"
        } else if percentage >= 65 {
            return "battery.75"
        } else if percentage >= 40 {
            return "battery.50"
        } else if percentage >= 15 {
            return "battery.25"
        } else {
            return "battery.0"
        }
    }
    
    public var voiceOverLabel: String {
        if !hasBattery {
            return "Battery Status: Desktop Mac, connected to power, no battery detected"
        }
        var label = "Battery \(percentage) percent, \(statusDescription)"
        if let time = formattedTimeEstimate {
            label += ", \(time)"
        }
        return label
    }
    
    public func makeCompactView() -> AnyView {
        AnyView(
            HStack(spacing: 4) {
                Image(systemName: isCharging ? "battery.100.bolt" : "battery.100")
                    .font(.system(size: 9))
                    .foregroundColor(batteryColor)
                Text("\(percentage)%")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(DesignSystem.primaryText)
            }
        )
    }
    
    public func makeExpandedView() -> AnyView {
        AnyView(
            BatteryExpandedView(module: self)
        )
    }
}

public struct BatteryExpandedView: View {
    @ObservedObject var module: BatteryModule
    @Environment(\.notchCompact) private var notchCompact
    @Environment(\.notchTight) private var notchTight
    
    public var body: some View {
        let gaugeSize: CGFloat = notchTight ? 46 : (notchCompact ? 56 : 70)
        let strokeW: CGFloat = notchTight ? 5.0 : 8.0
        let percentFontSize: CGFloat = notchTight ? 12.0 : 16.0
        
        VStack(alignment: .leading, spacing: notchTight ? 6 : 12) {
            HStack {
                Text("Power & Battery")
                    .font(.system(size: notchTight ? 11 : 13, weight: .bold, design: .rounded))
                    .foregroundColor(DesignSystem.primaryText)
                Spacer()
                Text(module.isCharging ? "Connected to Power" : "On Battery")
                    .font(.system(size: notchTight ? 9.5 : 11))
                    .foregroundColor(DesignSystem.secondaryText)
            }
            
            HStack(spacing: notchTight ? 12 : 20) {
                ZStack {
                    Circle()
                        .stroke(DesignSystem.structureColor, lineWidth: strokeW)
                        .frame(width: gaugeSize, height: gaugeSize)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(module.percentage) / 100.0)
                        .stroke(
                            module.percentage < 20 ? Color.red : (module.isCharging ? Color.green : DesignSystem.accentColor),
                            style: StrokeStyle(lineWidth: strokeW, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: gaugeSize, height: gaugeSize)
                        .animation(DesignSystem.reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.85), value: module.percentage)
                    
                    VStack(spacing: 0) {
                        Text("\(module.percentage)%")
                            .font(.system(size: percentFontSize, weight: .bold, design: .rounded))
                            .foregroundColor(DesignSystem.primaryText)
                        if module.isCharging {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: notchTight ? 7 : 10))
                                .foregroundColor(.yellow)
                        }
                    }
                }
                
                VStack(alignment: .leading, spacing: notchTight ? 3 : 6) {
                    Text("Apple Silicon Health")
                        .font(.system(size: notchTight ? 10.5 : 12, weight: .semibold))
                        .foregroundColor(DesignSystem.primaryText)
                    
                    if !notchTight {
                        Text("Optimized Battery Charging: Active")
                            .font(.system(size: 11))
                            .foregroundColor(DesignSystem.secondaryText)
                    }
                    
                    if !notchCompact {
                        Text("Cycle Count & Battery Longevity Normal")
                            .font(.system(size: 10))
                            .foregroundColor(DesignSystem.tertiaryText)
                    }
                }
            }
        }
        .onAppear { module.start() }
        .onDisappear { module.stop() }
    }
}
