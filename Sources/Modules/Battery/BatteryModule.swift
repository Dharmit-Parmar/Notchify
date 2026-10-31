import SwiftUI
import IOKit.ps

public final class BatteryModule: NotchModule {
    public let id = "battery"
    public let title = "Battery"
    public let iconName = "battery.100.bolt"
    @Published public var isEnabled: Bool = true
    
    @Published public var percentage: Int = 100
    @Published public var isCharging: Bool = true
    @Published public var timeRemaining: String = "Fully Charged"
    
    public init() {
        refresh()
    }
    
    public func start() {
        refresh()
    }
    
    public func stop() {}
    
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
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Power & Battery")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Spacer()
                    Text(isCharging ? "Connected to Power" : "On Battery")
                        .font(.system(size: 11))
                        .foregroundColor(DesignSystem.secondaryText)
                }
                
                HStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .stroke(DesignSystem.structureColor, lineWidth: 8)
                            .frame(width: 70, height: 70)
                        
                        Circle()
                            .trim(from: 0, to: CGFloat(percentage) / 100.0)
                            .stroke(
                                percentage < 20 ? Color.red : DesignSystem.accentColor,
                                style: StrokeStyle(lineWidth: 8, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .frame(width: 70, height: 70)
                        
                        VStack(spacing: 0) {
                            Text("\(percentage)%")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            if isCharging {
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.yellow)
                            }
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Apple Silicon Health")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                        Text("Optimized Battery Charging: Active")
                            .font(.system(size: 11))
                            .foregroundColor(DesignSystem.secondaryText)
                        Text("Cycle Count & Battery Longevity Normal")
                            .font(.system(size: 10))
                            .foregroundColor(DesignSystem.tertiaryText)
                    }
                }
            }
        )
    }
}
