import SwiftUI
import AppKit

public struct NotificationItem: Identifiable, Equatable {
    public let id: UUID
    public let appName: String
    public let appIconName: String
    public let title: String
    public let body: String
    public let timestamp: Date
    public let bundleId: String
    
    public init(id: UUID = UUID(), appName: String, appIconName: String, title: String, body: String, timestamp: Date = Date(), bundleId: String = "") {
        self.id = id
        self.appName = appName
        self.appIconName = appIconName
        self.title = title
        self.body = body
        self.timestamp = timestamp
        self.bundleId = bundleId
    }
}

@MainActor
public final class NotificationModule: NotchModule {
    public static let shared = NotificationModule()
    
    public let id = "notifications"
    public let title = "Notifications"
    public let iconName = "bell.fill"
    @Published public var isEnabled: Bool = true
    
    @Published public var notifications: [NotificationItem] = []
    
    public init() {}
    
    public func start() {}
    public func stop() {}
    
    public func addNotification(_ item: NotificationItem) {
        notifications.insert(item, at: 0)
        if notifications.count > DesignSystem.maxNotificationCards {
            notifications = Array(notifications.prefix(DesignSystem.maxNotificationCards))
        }
    }
    
    public func dismissNotification(id: UUID) {
        notifications.removeAll(where: { $0.id == id })
    }
    
    public func clearAll() {
        notifications.removeAll()
    }
    
    public func openSourceApp(for item: NotificationItem) {
        if !item.bundleId.isEmpty {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: item.bundleId) {
                NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
                return
            }
        }
        if let app = NSWorkspace.shared.runningApplications.first(where: { $0.localizedName?.lowercased() == item.appName.lowercased() }) {
            app.activate()
        }
    }
    
    public func makeCompactView() -> AnyView {
        AnyView(
            HStack(spacing: 5) {
                Image(systemName: "bell.fill")
                    .font(.system(size: 9))
                    .foregroundColor(DesignSystem.accentColor)
                Text("\(notifications.count)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
        )
    }
    
    public func makeExpandedView() -> AnyView {
        AnyView(
            NotificationModuleExpandedView(module: self)
        )
    }
}

public struct NotificationModuleExpandedView: View {
    @ObservedObject var module: NotificationModule
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Notch In-App Alerts")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("Activity stream for Notchify transfers, downloads, and events")
                        .font(.system(size: 10))
                        .foregroundColor(DesignSystem.secondaryText)
                }
                Spacer()
                if !module.notifications.isEmpty {
                    Button(action: {
                        FeedbackManager.playClick()
                        module.clearAll()
                    }) {
                        Text("Clear All")
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundColor(DesignSystem.accentColor)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear all notifications")
                }
                Text("Capped to \(DesignSystem.maxNotificationCards) items")
                    .font(.system(size: 10))
                    .foregroundColor(DesignSystem.tertiaryText)
            }
            
            if module.notifications.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "bell.slash")
                        .font(.system(size: 22))
                        .foregroundColor(DesignSystem.tertiaryText)
                    Text("No recent alerts")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(DesignSystem.secondaryText)
                    Text("In-app notifications for transfers, downloads, and system events will appear here")
                        .font(.system(size: 9.5))
                        .foregroundColor(DesignSystem.tertiaryText)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 8) {
                        ForEach(module.notifications) { item in
                            HStack(alignment: .top, spacing: 10) {
                                Button {
                                    FeedbackManager.playClick()
                                    module.openSourceApp(for: item)
                                } label: {
                                    HStack(alignment: .top, spacing: 10) {
                                        Image(systemName: item.appIconName)
                                            .font(.system(size: 14))
                                            .foregroundColor(DesignSystem.accentColor)
                                            .frame(width: 20)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(item.appName)
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundColor(DesignSystem.secondaryText)
                                            Text(item.title)
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundColor(.white)
                                            Text(item.body)
                                                .font(.system(size: 11))
                                                .foregroundColor(DesignSystem.secondaryText)
                                                .lineLimit(2)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.spring)
                                .accessibilityLabel("Open \(item.appName) notification")

                                Button {
                                    module.dismissNotification(id: item.id)
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 9))
                                        .foregroundColor(DesignSystem.tertiaryText)
                                }
                                .buttonStyle(.spring(scale: 0.94))
                                .accessibilityLabel("Dismiss notification")
                            }
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(DesignSystem.structureColor)
                            )
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
