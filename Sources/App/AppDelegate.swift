import AppKit
import SwiftUI
import Combine

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    public static var isSettingsOpen: Bool = false
    public private(set) static var settingsWindow: NSWindow?
    private static var delegateInstance: AppDelegate?
    
    public static var sharedDelegate: AppDelegate {
        if let instance = delegateInstance { return instance }
        let newInstance = AppDelegate()
        delegateInstance = newInstance
        return newInstance
    }
    
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
        
        // Register secondary feature modules for header tabs (AirDrop, File Studio, Thock, Messages, Battery, Mirror, Notifications)
        let registry = ModuleRegistry.shared
        registry.register(AirDropModule.shared)
        registry.register(ShelfModule.shared)
        registry.register(ThockModule.shared)
        registry.register(TelegramModule())
        registry.register(BatteryModule.shared)
        registry.register(MirrorModule.shared)
        registry.register(NotificationModule())
        
        // Ensure standard /Applications and ~/Applications bundle discovery
        PermissionsHelper.ensureApplicationsSymlink()
        
        setupMainMenu()
        setupStatusItem()
        setupNotchPanel()
        setupSettingsObserver()
    }
    
    private func setupMainMenu() {
        let mainMenu = NSMenu()
        
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        appMenu.addItem(withTitle: "About Notch", action: #selector(openPreferences), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Preferences...", action: #selector(openPreferences), keyEquivalent: ",")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Quit Notch", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        
        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "Edit")
        editMenuItem.submenu = editMenu
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redoItem = NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        redoItem.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(redoItem)
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        
        NSApp.mainMenu = mainMenu
    }
    
    private func setupSettingsObserver() {
        Publishers.CombineLatest4(
            SettingsStore.shared.$notchWidth,
            SettingsStore.shared.$notchHeight,
            SettingsStore.shared.$hoverTriggerHeight,
            SettingsStore.shared.$hoverTriggerWidth
        )
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
        
        let hostingView = NotchHostingView(rootView: NotchRootView())
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
        if !SettingsStore.shared.keepOpenWhileSettingsActive {
            NotchShellCoordinator.shared.collapseImmediately()
        }
        
        if let window = settingsWindow {
            isSettingsOpen = true
            if window.isMiniaturized {
                window.deminiaturize(nil)
            }
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 820, height: 620),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.minSize = NSSize(width: 780, height: 560)
        window.setFrameAutosaveName("NotchIslandSettingsWindow")
        if window.frame.width < 780 || window.frame.height < 560 {
            window.setContentSize(NSSize(width: 820, height: 620))
        }
        if let screen = NSScreen.main ?? NSScreen.screens.first {
            let screenFrame = screen.visibleFrame
            let winW: CGFloat = max(820, window.frame.width)
            let winH: CGFloat = min(screenFrame.height - 40, max(620, window.frame.height))
            let originX = screenFrame.midX - (winW / 2)
            let originY = max(screenFrame.minY + 20, screenFrame.maxY - winH - 24)
            window.setFrame(NSRect(x: originX, y: originY, width: winW, height: winH), display: true)
        } else {
            window.center()
        }
        window.title = "Notch Island Preferences"
        window.contentView = NSHostingView(rootView: SettingsView())
        window.isReleasedWhenClosed = false
        window.level = .statusBar + 1
        window.delegate = AppDelegate.sharedDelegate
        
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak window] _ in
            Task { @MainActor [weak window] in
                guard AppDelegate.isSettingsOpen || AppDelegate.settingsWindow === window else { return }
                AppDelegate.isSettingsOpen = false
                AppDelegate.settingsWindow = nil
                if NotchShellCoordinator.shared.state == .expanded,
                   !NotchShellCoordinator.shared.isLockedOpen,
                   let panel = NotchShellCoordinator.shared.panel,
                   !panel.frame.contains(NSEvent.mouseLocation) {
                    NotchShellCoordinator.shared.collapseImmediately()
                }
            }
        }
        
        isSettingsOpen = true
        settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    public static func closeSettingsWindow() {
        guard isSettingsOpen || settingsWindow != nil else { return }
        isSettingsOpen = false
        let win = settingsWindow
        settingsWindow = nil
        win?.close()
        
        if NotchShellCoordinator.shared.state == .expanded,
           !NotchShellCoordinator.shared.isLockedOpen,
           let panel = NotchShellCoordinator.shared.panel,
           !panel.frame.contains(NSEvent.mouseLocation) {
            NotchShellCoordinator.shared.collapseImmediately()
        }
    }
    
    public func windowWillClose(_ notification: Notification) {
        if let closingWindow = notification.object as? NSWindow,
           closingWindow === AppDelegate.settingsWindow {
            AppDelegate.isSettingsOpen = false
            AppDelegate.settingsWindow = nil
            if NotchShellCoordinator.shared.state == .expanded,
               !NotchShellCoordinator.shared.isLockedOpen,
               let panel = NotchShellCoordinator.shared.panel,
               !panel.frame.contains(NSEvent.mouseLocation) {
                NotchShellCoordinator.shared.collapseImmediately()
            }
        }
    }
    
    public func applicationWillTerminate(_ notification: Notification) {
        ThockModule.shared.terminateProcess()
        ShelfModule.shared.cleanStaleTempFiles(all: true)
    }
}
