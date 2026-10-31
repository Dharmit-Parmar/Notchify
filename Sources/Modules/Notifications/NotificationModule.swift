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
    public let id = "notifications"
    public let title = "Notifications"
    public let iconName = "bell.fill"
    @Published public var isEnabled: Bool = true
    
    @Published public var notifications: [NotificationItem] = []
    
    public init() {
        loadMockInitialNotifications()
    }
    
    public func start() {}
    public func stop() {}
    
    private func loadMockInitialNotifications() {
        // Safe starting items demonstrating notification mirroring
        notifications = [
            NotificationItem(
                appName: "Calendar",
                appIconName: "calendar",
                title: "Sprint Review & Planning",
                body: "In 15 minutes",
                bundleId: "com.apple.iCal"
            ),
            NotificationItem(
                appName: "Messages",
                appIconName: "message.fill",
                title: "New Alert",
                body: "All system services operating normally.",
                bundleId: "com.apple.MobileSMS"
            )
        ]
    }
    
    public func addNotification(_ item: NotificationItem) {
        notifications.insert(item, at: 0)
        if notifications.count > DesignSystem.maxNotificationCards {
            notifications = Array(notifications.prefix(DesignSystem.maxNotificationCards))
        }
    }
    
    public func dismissNotification(id: UUID) {
        notifications.removeAll(where: { $0.id == id })
    }
    
    public func openSourceApp(for item: NotificationItem) {
        if !item.bundleId.isEmpty {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: item.bundleId) {
                NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
            }
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
                Text("Notification Stream")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                Text("Capped to \(DesignSystem.maxNotificationCards) items")
                    .font(.system(size: 10))
                    .foregroundColor(DesignSystem.tertiaryText)
            }
            
            if module.notifications.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "bell.slash")
                        .font(.system(size: 22))
                        .foregroundColor(DesignSystem.tertiaryText)
                    Text("No recent notifications")
                        .font(.system(size: 11))
                        .foregroundColor(DesignSystem.secondaryText)
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
                .frame(maxHeight: 120)
            }
        }
    }
}
