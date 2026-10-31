import AppKit
import SwiftUI
import Combine

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    public static var isSettingsOpen: Bool = false
    private static var settingsWindow: NSWindow?
    private static var delegateInstance: AppDelegate?
    
    private var notchPanel: NotchPanel?
    private var statusItem: NSStatusItem?
    private var cancellables = Set<AnyCancellable>()
    
    public func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.delegateInstance = self
        
        // Single-instance enforcement: kill any stale duplicate NotchApp processes
        let myPID = ProcessInfo.processInfo.processIdentifier
        let running = NSWorkspace.shared.runningApplications
        for app in running {
            if (app.localizedName == "NotchApp" || app.bundleIdentifier == "com.notch.NotchApp") && app.processIdentifier != myPID {
                app.terminate()
            }
        }
        
        // Load current media state; periodic polling starts only while the notch is expanded.
        _ = NowPlayingModule.shared
        _ = CalendarModule.shared
        
        // Register secondary feature modules for header tabs (AirDrop, File Studio, Messages, Battery, Mirror, Notifications)
        let registry = ModuleRegistry.shared
        registry.register(AirDropModule.shared)
        registry.register(ShelfModule.shared)
        registry.register(TelegramModule())
        registry.register(BatteryModule())
        registry.register(MirrorModule())
        registry.register(NotificationModule())
        
        setupStatusItem()
        setupNotchPanel()
        setupSettingsObserver()
    }
    
    private func setupSettingsObserver() {
        SettingsStore.shared.$notchWidth
            .combineLatest(SettingsStore.shared.$notchHeight, SettingsStore.shared.$hoverTriggerHeight)
            .dropFirst()
            .sink { [weak self] _ in
                guard let self = self, let panel = self.notchPanel else { return }
                panel.updateFrame(for: NotchShellCoordinator.shared.state, animated: false)
            }
            .store(in: &cancellables)
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "menubar.dock.rectangle", accessibilityDescription: "Notch App")
        }
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Toggle Notch Island", action: #selector(toggleNotch), keyEquivalent: "n"))
        menu.addItem(NSMenuItem(title: "Preferences & Themes...", action: #selector(openPreferences), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Notch", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem?.menu = menu
    }
    
    private func setupNotchPanel() {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let panel = NotchPanel(screen: screen)
        
        let hostingView = NSHostingView(rootView: NotchRootView())
        hostingView.autoresizingMask = [.width, .height]
        panel.contentView = hostingView
        
        NotchShellCoordinator.shared.panel = panel
        
        panel.orderFrontRegardless()
        self.notchPanel = panel
    }
    
    @objc private func toggleNotch() {
        NotchShellCoordinator.shared.toggleLock()
    }
    
    @objc private func openPreferences() {
        AppDelegate.openSettingsWindow()
    }
    
    public static func openSettingsWindow() {
        if let window = settingsWindow {
            isSettingsOpen = true
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 600),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Notch Island Preferences"
        window.contentView = NSHostingView(rootView: SettingsView())
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.delegate = AppDelegate.delegateInstance
        
        isSettingsOpen = true
        settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    public func windowWillClose(_ notification: Notification) {
        if let closingWindow = notification.object as? NSWindow,
           closingWindow === AppDelegate.settingsWindow {
            AppDelegate.isSettingsOpen = false
            AppDelegate.settingsWindow = nil
        }
    }
}
