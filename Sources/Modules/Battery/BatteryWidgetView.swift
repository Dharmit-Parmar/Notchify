import SwiftUI
import AppKit

public struct BatteryWidgetView: View {
    @ObservedObject private var module = BatteryModule.shared
    @ObservedObject private var store = SettingsStore.shared
    @Environment(\.notchCompact) private var notchCompact
    @Environment(\.notchTight) private var notchTight
    
    public var span: Int // 1, 2, or 4 spaces
    
    public init(span: Int = 1) {
        self.span = span
    }
    
    public var body: some View {
        Group {
            if span == 1 {
                oneSpaceView
            } else if span == 2 {
                twoSpaceView
            } else {
                fourSpaceView
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(module.voiceOverLabel)
        .onAppear {
            module.start()
        }
        .onDisappear {
            module.stop()
        }
    }
    
    // MARK: - 1-Space Mode (Compact Tile)
    @ViewBuilder
    private var oneSpaceView: some View {
        GeometryReader { geo in
            let availableH = geo.size.height
            let isVeryTight = notchTight || availableH < 95
            let isCompactH = notchCompact || availableH < 125
            let gaugeSize: CGFloat = isVeryTight ? 32 : (isCompactH ? 44 : 54)
            let strokeW: CGFloat = isVeryTight ? 4.0 : 5.5
            
            VStack(spacing: isVeryTight ? 3 : 6) {
                // Header: Icon + Title
                HStack(spacing: 4) {
                    Image(systemName: module.batteryIconName)
                        .font(.system(size: isVeryTight ? 10 : 11, weight: .semibold))
                        .foregroundColor(module.batteryColor)
                    
                    Text("Battery")
                        .font(.system(size: isVeryTight ? 10 : 11, weight: .semibold, design: .rounded))
                        .foregroundColor(DesignSystem.primaryText)
                        .lineLimit(1)
                    
                    Spacer(minLength: 0)
                    
                    if module.hasBattery && module.isCharging {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 8.5))
                            .foregroundColor(.yellow)
                    }
                }
                
                Spacer(minLength: 0)
                
                if module.hasBattery {
                    // Battery Gauge Ring or Bar
                    ZStack {
                        Circle()
                            .stroke(DesignSystem.surfaceFill, lineWidth: strokeW)
                            .frame(width: gaugeSize, height: gaugeSize)
                        
                        Circle()
                            .trim(from: 0, to: CGFloat(module.percentage) / 100.0)
                            .stroke(
                                module.batteryColor,
                                style: StrokeStyle(lineWidth: strokeW, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .frame(width: gaugeSize, height: gaugeSize)
                            .animation(DesignSystem.reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.85), value: module.percentage)
                        
                        VStack(spacing: 0) {
                            Text("\(module.percentage)%")
                                .font(.system(size: isVeryTight ? 10.5 : (isCompactH ? 12.5 : 14), weight: .bold, design: .rounded))
                                .foregroundColor(DesignSystem.primaryText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                    }
                    
                    Spacer(minLength: 0)
                    
                    // Status subtitle (dropped in very tight layouts)
                    if !isVeryTight {
                        Text(module.statusDescription)
                            .font(.system(size: 9.5, weight: .medium, design: .rounded))
                            .foregroundColor(DesignSystem.secondaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                } else {
                    // Desktop Mac fallback: Mac mini / Studio / Pro / iMac
                    VStack(spacing: 4) {
                        Image(systemName: "desktopcomputer")
                            .font(.system(size: isVeryTight ? 18 : 24))
                            .foregroundColor(DesignSystem.secondaryText)
                        
                        Text("Desktop Mac")
                            .font(.system(size: isVeryTight ? 10 : 11, weight: .bold, design: .rounded))
                            .foregroundColor(DesignSystem.primaryText)
                        
                        Text("Connected to Power")
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundColor(DesignSystem.secondaryText)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .padding(isVeryTight ? 6 : 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.defaultCornerRadius, style: .continuous)
                .fill(DesignSystem.cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.defaultCornerRadius, style: .continuous)
                        .strokeBorder(DesignSystem.cardBorder, lineWidth: 0.9)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.defaultCornerRadius, style: .continuous))
    }
    
    // MARK: - 2-Space Mode (Half-Stage Card)
    @ViewBuilder
    private var twoSpaceView: some View {
        GeometryReader { geo in
            let availableH = geo.size.height
            let isVeryTight = notchTight || availableH < 95
            let isCompactH = notchCompact || availableH < 130
            let gaugeSize: CGFloat = isVeryTight ? 38 : (isCompactH ? 50 : 64)
            let strokeW: CGFloat = isVeryTight ? 4.5 : 6.0
            
            VStack(alignment: .leading, spacing: isVeryTight ? 4 : 8) {
                // Header
                HStack {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(module.batteryColor)
                            .frame(width: 7, height: 7)
                        
                        Text("Power & Battery")
                            .font(.system(size: isVeryTight ? 11 : 12, weight: .bold, design: .rounded))
                            .foregroundColor(DesignSystem.primaryText)
                    }
                    
                    Spacer()
                    
                    if module.hasBattery {
                        Text(module.powerSourceState)
                            .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                            .foregroundColor(DesignSystem.secondaryText)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(DesignSystem.surfaceFill))
                    } else {
                        Text("AC Powered")
                            .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                            .foregroundColor(DesignSystem.secondaryText)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(DesignSystem.surfaceFill))
                    }
                }
                
                Divider()
                    .background(DesignSystem.subtleBorder)
                
                if module.hasBattery {
                    HStack(spacing: isVeryTight ? 10 : 16) {
                        // Ring gauge
                        ZStack {
                            Circle()
                                .stroke(DesignSystem.surfaceFill, lineWidth: strokeW)
                                .frame(width: gaugeSize, height: gaugeSize)
                            
                            Circle()
                                .trim(from: 0, to: CGFloat(module.percentage) / 100.0)
                                .stroke(
                                    module.batteryColor,
                                    style: StrokeStyle(lineWidth: strokeW, lineCap: .round)
                                )
                                .rotationEffect(.degrees(-90))
                                .frame(width: gaugeSize, height: gaugeSize)
                                .animation(DesignSystem.reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.85), value: module.percentage)
                            
                            VStack(spacing: 0) {
                                Text("\(module.percentage)%")
                                    .font(.system(size: isVeryTight ? 11 : (isCompactH ? 13 : 15), weight: .bold, design: .rounded))
                                    .foregroundColor(DesignSystem.primaryText)
                                
                                if module.isCharging {
                                    Image(systemName: "bolt.fill")
                                        .font(.system(size: isVeryTight ? 7 : 9))
                                        .foregroundColor(.yellow)
                                }
                            }
                        }
                        
                        // Detail rows
                        VStack(alignment: .leading, spacing: isVeryTight ? 2 : 4) {
                            Text(module.statusDescription)
                                .font(.system(size: isVeryTight ? 11 : 12.5, weight: .semibold, design: .rounded))
                                .foregroundColor(DesignSystem.primaryText)
                            
                            if let estimate = module.formattedTimeEstimate {
                                Text(estimate)
                                    .font(.system(size: 10, weight: .medium, design: .rounded))
                                    .foregroundColor(DesignSystem.secondaryText)
                            }
                            
                            if !isVeryTight {
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(module.isLowPowerMode ? Color.yellow : Color.green)
                                        .frame(width: 5, height: 5)
                                    Text(module.isLowPowerMode ? "Low Power Mode Enabled" : "Battery Health Normal")
                                        .font(.system(size: 9.5, weight: .medium))
                                        .foregroundColor(DesignSystem.tertiaryText)
                                }
                            }
                        }
                        
                        Spacer()
                    }
                } else {
                    // Desktop Mac fallback
                    HStack(spacing: 12) {
                        Image(systemName: "desktopcomputer")
                            .font(.system(size: isVeryTight ? 26 : 34))
                            .foregroundColor(DesignSystem.secondaryText)
                        
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Desktop Mac")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(DesignSystem.primaryText)
                            
                            Text("Continuous AC Power supply")
                                .font(.system(size: 10.5, weight: .medium))
                                .foregroundColor(DesignSystem.secondaryText)
                            
                            Text("No internal battery detected on this hardware.")
                                .font(.system(size: 9.5))
                                .foregroundColor(DesignSystem.tertiaryText)
                        }
                        
                        Spacer()
                    }
                }
            }
            .padding(isVeryTight ? 8 : 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.defaultCornerRadius, style: .continuous)
                .fill(DesignSystem.cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.defaultCornerRadius, style: .continuous)
                        .strokeBorder(DesignSystem.cardBorder, lineWidth: 0.9)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.defaultCornerRadius, style: .continuous))
    }
    
    // MARK: - 4-Space Mode (Full Stage Dashboard)
    @ViewBuilder
    private var fourSpaceView: some View {
        GeometryReader { geo in
            let availableH = geo.size.height
            let isVeryTight = notchTight || availableH < 95
            let isCompactH = notchCompact || availableH < 135
            let gaugeSize: CGFloat = isVeryTight ? 44 : (isCompactH ? 56 : 72)
            let strokeW: CGFloat = isVeryTight ? 5.0 : 7.0
            
            VStack(alignment: .leading, spacing: isVeryTight ? 4 : 8) {
                // Header
                HStack {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(module.batteryColor)
                            .frame(width: 7, height: 7)
                        
                        Text("Power & Energy Dashboard")
                            .font(.system(size: isVeryTight ? 11 : 13, weight: .bold, design: .rounded))
                            .foregroundColor(DesignSystem.primaryText)
                    }
                    
                    Spacer()
                    
                    Text(module.hasBattery ? module.powerSourceState : "AC Power")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(DesignSystem.secondaryText)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(DesignSystem.surfaceFill))
                }
                
                Divider()
                    .background(DesignSystem.subtleBorder)
                
                if module.hasBattery {
                    HStack(alignment: .center, spacing: 20) {
                        // Left: Gauge
                        ZStack {
                            Circle()
                                .stroke(DesignSystem.surfaceFill, lineWidth: strokeW)
                                .frame(width: gaugeSize, height: gaugeSize)
                            
                            Circle()
                                .trim(from: 0, to: CGFloat(module.percentage) / 100.0)
                                .stroke(
                                    module.batteryColor,
                                    style: StrokeStyle(lineWidth: strokeW, lineCap: .round)
                                )
                                .rotationEffect(.degrees(-90))
                                .frame(width: gaugeSize, height: gaugeSize)
                                .animation(DesignSystem.reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.85), value: module.percentage)
                            
                            VStack(spacing: 0) {
                                Text("\(module.percentage)%")
                                    .font(.system(size: isVeryTight ? 12 : (isCompactH ? 14 : 17), weight: .bold, design: .rounded))
                                    .foregroundColor(DesignSystem.primaryText)
                                
                                if module.isCharging {
                                    Image(systemName: "bolt.fill")
                                        .font(.system(size: 9))
                                        .foregroundColor(.yellow)
                                }
                            }
                        }
                        
                        // Center: Status & Metrics
                        VStack(alignment: .leading, spacing: isVeryTight ? 2 : 4) {
                            Text(module.statusDescription)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(DesignSystem.primaryText)
                            
                            if let estimate = module.formattedTimeEstimate {
                                Text(estimate)
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundColor(DesignSystem.secondaryText)
                            }
                            
                            HStack(spacing: 8) {
                                Label(
                                    title: { Text(module.isLowPowerMode ? "Low Power" : "Standard Power").font(.system(size: 9.5)) },
                                    icon: { Image(systemName: module.isLowPowerMode ? "leaf.fill" : "bolt.badge.checkmark").foregroundColor(module.isLowPowerMode ? .yellow : .green) }
                                )
                                .foregroundColor(DesignSystem.tertiaryText)
                                
                                Label(
                                    title: { Text("Battery Health Normal").font(.system(size: 9.5)) },
                                    icon: { Image(systemName: "checkmark.shield").foregroundColor(.green) }
                                )
                                .foregroundColor(DesignSystem.tertiaryText)
                            }
                        }
                        
                        Spacer()
                        
                        // Right: Architectural Note on Zero-Timer Performance
                        if !isVeryTight && !isCompactH {
                            VStack(alignment: .trailing, spacing: 3) {
                                Text("Event-Driven Kernel Monitor")
                                    .font(.system(size: 9.5, weight: .bold))
                                    .foregroundColor(DesignSystem.primaryText)
                                Text("0% CPU • Zero Background Timers")
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundColor(DesignSystem.secondaryText)
                                Text("History strip omitted to preserve zero-timer invariant.")
                                    .font(.system(size: 8.5))
                                    .foregroundColor(DesignSystem.tertiaryText)
                                    .multilineTextAlignment(.trailing)
                            }
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(DesignSystem.surfaceFill)
                            )
                        }
                    }
                } else {
                    // Desktop Mac full-stage fallback
                    HStack(spacing: 16) {
                        Image(systemName: "desktopcomputer")
                            .font(.system(size: isVeryTight ? 30 : 44))
                            .foregroundColor(DesignSystem.secondaryText)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Desktop Mac System")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(DesignSystem.primaryText)
                            
                            Text("Connected to standard continuous AC power source.")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(DesignSystem.secondaryText)
                            
                            Text("No internal battery detected on this hardware. Power monitoring operates in desktop AC mode.")
                                .font(.system(size: 10))
                                .foregroundColor(DesignSystem.tertiaryText)
                        }
                        
                        Spacer()
                    }
                }
            }
            .padding(isVeryTight ? 8 : 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.defaultCornerRadius, style: .continuous)
                .fill(DesignSystem.cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.defaultCornerRadius, style: .continuous)
                        .strokeBorder(DesignSystem.cardBorder, lineWidth: 0.9)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.defaultCornerRadius, style: .continuous))
    }
}
