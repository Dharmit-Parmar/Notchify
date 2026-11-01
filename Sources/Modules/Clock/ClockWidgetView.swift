import SwiftUI

// MARK: - Zero-Allocation Static Date Formatters
private enum ClockFormatters {
    static let time24WithSeconds: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()
    
    static let time24NoSeconds: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()
    
    static let time12WithSeconds: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm:ss a"
        return f
    }()
    
    static let time12NoSeconds: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()
    
    static let hourMinute24: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()
    
    static let hourMinute12: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm"
        return f
    }()
    
    static let seconds: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "ss"
        return f
    }()
    
    static let amPm: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "a"
        return f
    }()
    
    static let dayOfWeek: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        return f
    }()
    
    static let dateShort: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f
    }()
    
    static let dateLong: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d, yyyy"
        return f
    }()
    
    static let utcTime: DateFormatter = {
        let f = DateFormatter()
        f.timeZone = TimeZone(abbreviation: "UTC")
        f.dateFormat = "HH:mm"
        return f
    }()
}

public struct ClockWidgetView: View {
    @ObservedObject private var store = SettingsStore.shared
    @ObservedObject private var coordinator = NotchShellCoordinator.shared
    public var span: Int // 1, 2, or 4 spaces
    
    public init(span: Int = 1) {
        self.span = span
    }
    
    /// Only analog chronometer with visible seconds benefits from 30fps animation.
    /// Digital clock only advances once per second, so 30fps is throttled to 1.0s to save CPU and battery.
    private var isSweepingAnalog: Bool {
        store.clockShowSeconds && (span == 1 || store.clockDialStyle == .analog)
    }
    
    private var minimumInterval: Double {
        isSweepingAnalog ? (1.0 / 30.0) : 1.0
    }
    
    public var body: some View {
        // Gates TimelineView: completely pauses when Notch is collapsed, eliminating background CPU draw!
        TimelineView(.animation(minimumInterval: minimumInterval, paused: coordinator.state != .expanded)) { timeline in
            let date = timeline.date
            Group {
                if span == 1 {
                    oneSpaceView(date: date)
                } else if span == 2 {
                    twoSpaceView(date: date)
                } else {
                    fourSpaceView(date: date)
                }
            }
        }
    }
    
    // MARK: - 1-Space Mode
    @ViewBuilder
    private func oneSpaceView(date: Date) -> some View {
        VStack(spacing: 6) {
            // Centered analog quartz dial (70pt) with smooth sweeping second hand
            AnalogClockFace(date: date, showSeconds: store.clockShowSeconds, size: 70)
                .frame(width: 70, height: 70)
            
            // Bold digital readout
            Text(digitalTimeString(date))
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
            
            // Day/date pill
            Text(dayOfWeekString(date).uppercased() + " · " + dateFormattedString(date))
                .font(.system(size: 8.5, weight: .medium, design: .rounded))
                .foregroundColor(DesignSystem.secondaryText)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, 7)
                .padding(.vertical, 2.5)
                .background(Capsule().fill(Color.white.opacity(0.08)))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.defaultCornerRadius, style: .continuous)
                .fill(DesignSystem.cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.defaultCornerRadius, style: .continuous)
                        .strokeBorder(DesignSystem.cardBorder, lineWidth: 0.9)
                )
        )
    }
    
    // MARK: - 2-Space Mode
    @ViewBuilder
    private func twoSpaceView(date: Date) -> some View {
        VStack(spacing: 10) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color(red: 0.35, green: 0.85, blue: 0.65))
                        .frame(width: 7, height: 7)
                    Text("Time & World Clock")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                Text(timeZoneAbbreviation)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(DesignSystem.secondaryText)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.white.opacity(0.08)))
            }
            
            if store.clockDialStyle == .analog {
                // Large Chronometer Dial
                HStack(spacing: 16) {
                    AnalogClockFace(date: date, showSeconds: store.clockShowSeconds, size: 120)
                        .frame(width: 120, height: 120)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text(dayOfWeekString(date))
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(Color(red: 0.35, green: 0.85, blue: 0.65))
                        
                        Text(digitalTimeString(date))
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text(dateFormattedString(date))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(DesignSystem.secondaryText)
                        
                        Divider().background(Color.white.opacity(0.12))
                        
                        // Secondary Timezone Glance
                        HStack(spacing: 8) {
                            Text("UTC")
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundColor(DesignSystem.secondaryText)
                            Text(utcTimeString(date))
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundColor(.white)
                        }
                    }
                    Spacer()
                }
            } else {
                // Large Digital Showcase
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(digitalHourMinuteString(date))
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        if store.clockShowSeconds {
                            Text(":\(secondString(date))")
                                .font(.system(size: 22, weight: .semibold, design: .monospaced))
                                .foregroundColor(Color(red: 0.35, green: 0.85, blue: 0.65))
                        }
                        
                        if !store.clockIs24Hour {
                            Text(amPmString(date))
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(DesignSystem.secondaryText)
                        }
                    }
                    
                    Text(fullLongDateString(date))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(DesignSystem.secondaryText)
                    
                    Divider().background(Color.white.opacity(0.12))
                    
                    // Timezone Grid
                    HStack(spacing: 12) {
                        TimezonePill(title: "Cupertino", offsetHours: -8, baseDate: date)
                        TimezonePill(title: "London", offsetHours: 0, baseDate: date)
                        TimezonePill(title: "Tokyo", offsetHours: 9, baseDate: date)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.defaultCornerRadius, style: .continuous)
                .fill(DesignSystem.cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.defaultCornerRadius, style: .continuous)
                        .strokeBorder(DesignSystem.cardBorder, lineWidth: 0.9)
                )
        )
    }
    
    // MARK: - 4-Space Mode
    @ViewBuilder
    private func fourSpaceView(date: Date) -> some View {
        HStack(spacing: 20) {
            // Left: Analog Chronometer
            AnalogClockFace(date: date, showSeconds: store.clockShowSeconds, size: 140)
                .frame(width: 140, height: 140)
            
            Divider().background(Color.white.opacity(0.12))
            
            // Right: Rich Digital & World Clock
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(digitalHourMinuteString(date))
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    if store.clockShowSeconds {
                        Text(":\(secondString(date))")
                            .font(.system(size: 20, weight: .semibold, design: .monospaced))
                            .foregroundColor(Color(red: 0.35, green: 0.85, blue: 0.65))
                    }
                    
                    if !store.clockIs24Hour {
                        Text(amPmString(date))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(DesignSystem.secondaryText)
                    }
                }
                
                Text(fullLongDateString(date))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(DesignSystem.secondaryText)
                
                HStack(spacing: 12) {
                    TimezonePill(title: "Cupertino", offsetHours: -8, baseDate: date)
                    TimezonePill(title: "London", offsetHours: 0, baseDate: date)
                    TimezonePill(title: "Tokyo", offsetHours: 9, baseDate: date)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.defaultCornerRadius, style: .continuous)
                .fill(DesignSystem.cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.defaultCornerRadius, style: .continuous)
                        .strokeBorder(DesignSystem.cardBorder, lineWidth: 0.9)
                )
        )
    }
    
    // MARK: - Zero-Allocation Formatting Helpers
    private func digitalTimeString(_ date: Date) -> String {
        if store.clockIs24Hour {
            return store.clockShowSeconds ? ClockFormatters.time24WithSeconds.string(from: date) : ClockFormatters.time24NoSeconds.string(from: date)
        } else {
            return store.clockShowSeconds ? ClockFormatters.time12WithSeconds.string(from: date) : ClockFormatters.time12NoSeconds.string(from: date)
        }
    }
    
    private func digitalHourMinuteString(_ date: Date) -> String {
        return store.clockIs24Hour ? ClockFormatters.hourMinute24.string(from: date) : ClockFormatters.hourMinute12.string(from: date)
    }
    
    private func secondString(_ date: Date) -> String {
        return ClockFormatters.seconds.string(from: date)
    }
    
    private func amPmString(_ date: Date) -> String {
        return ClockFormatters.amPm.string(from: date)
    }
    
    private func dayOfWeekString(_ date: Date) -> String {
        return ClockFormatters.dayOfWeek.string(from: date)
    }
    
    private func dateFormattedString(_ date: Date) -> String {
        return ClockFormatters.dateShort.string(from: date)
    }
    
    private func fullLongDateString(_ date: Date) -> String {
        return ClockFormatters.dateLong.string(from: date)
    }
    
    private func utcTimeString(_ date: Date) -> String {
        return ClockFormatters.utcTime.string(from: date)
    }
    
    private var timeZoneAbbreviation: String {
        TimeZone.current.abbreviation() ?? "LOCAL"
    }
}

// MARK: - Analog Clock Face
struct AnalogClockFace: View {
    let date: Date
    let showSeconds: Bool
    let size: CGFloat
    
    var body: some View {
        let calendar = Calendar.current
        let second = Double(calendar.component(.second, from: date))
        let nanosecond = Double(calendar.component(.nanosecond, from: date))
        let minute = Double(calendar.component(.minute, from: date))
        let hour = Double(calendar.component(.hour, from: date))
        
        let smoothSecond = second + (nanosecond / 1_000_000_000.0)
        let smoothMinute = minute + (smoothSecond / 60.0)
        let smoothHour = (hour.truncatingRemainder(dividingBy: 12)) + (smoothMinute / 60.0)
        
        ZStack {
            // Dial background
            Circle()
                .fill(Color.black.opacity(0.35))
                .overlay(
                    Circle()
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1.0)
                )
            
            // Hour ticks
            ForEach(0..<12) { tick in
                Rectangle()
                    .fill(tick % 3 == 0 ? Color.white.opacity(0.7) : Color.white.opacity(0.25))
                    .frame(width: tick % 3 == 0 ? 2 : 1, height: tick % 3 == 0 ? 6 : 4)
                    .offset(y: -(size / 2 - 6))
                    .rotationEffect(.degrees(Double(tick) * 30))
            }
            
            // Hour Hand
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.white)
                .frame(width: 3.2, height: size * 0.28)
                .offset(y: -(size * 0.14))
                .rotationEffect(.degrees(smoothHour * 30))
            
            // Minute Hand
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Color.white.opacity(0.85))
                .frame(width: 2.2, height: size * 0.38)
                .offset(y: -(size * 0.19))
                .rotationEffect(.degrees(smoothMinute * 6))
            
            // Second Hand
            if showSeconds {
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color(red: 0.98, green: 0.45, blue: 0.22)) // Apple Watch Orange second hand
                    .frame(width: 1.2, height: size * 0.45)
                    .offset(y: -(size * 0.18))
                    .rotationEffect(.degrees(smoothSecond * 6))
                
                Circle()
                    .fill(Color(red: 0.98, green: 0.45, blue: 0.22))
                    .frame(width: 4, height: 4)
            } else {
                Circle()
                    .fill(Color.white)
                    .frame(width: 4, height: 4)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Secondary Timezone Pill
struct TimezonePill: View {
    let title: String
    let offsetHours: Int
    let baseDate: Date
    
    private var targetTime: String {
        let target = baseDate.addingTimeInterval(Double(offsetHours) * 3600)
        return ClockFormatters.hourMinute24.string(from: target)
    }
    
    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(DesignSystem.secondaryText)
            Text(targetTime)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.06)))
    }
}
