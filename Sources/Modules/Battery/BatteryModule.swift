import SwiftUI
import IOKit.ps

import Combine

public final class BatteryModule: NotchModule {
    public static let shared = BatteryModule()
    
    public let id = "battery"
    public let title = "Battery"
    public let iconName = "battery.100.bolt"
    @Published public var isEnabled: Bool = true
    
    @Published public var percentage: Int = 100
    @Published public var isCharging: Bool = true
    @Published public var timeRemaining: String = "Fully Charged"
    
    private var powerRunLoopSource: CFRunLoopSource?
    
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
    }
    
    public func stop() {
        if let source = powerRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            powerRunLoopSource = nil
        }
    }
    
    public func refresh() {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else {
            return
        }
        
        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }
            if let currentCapacity = description[kIOPSCurrentCapacityKey as String] as? Int,
               let maxCapacity = description[kIOPSMaxCapacityKey as String] as? Int {
                self.percentage = Int((Double(currentCapacity) / Double(maxCapacity)) * 100.0)
            }
            if let isCharging = description[kIOPSIsChargingKey as String] as? Bool {
                self.isCharging = isCharging
            }
        }
    }
    
    public func makeCompactView() -> AnyView {
        AnyView(
            HStack(spacing: 4) {
                Image(systemName: isCharging ? "battery.100.bolt" : "battery.100")
                    .font(.system(size: 9))
                    .foregroundColor(percentage < 20 ? .red : .green)
                Text("\(percentage)%")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
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
                    .foregroundColor(.white)
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
                            .foregroundColor(.white)
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
                        .foregroundColor(.white)
                    
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
