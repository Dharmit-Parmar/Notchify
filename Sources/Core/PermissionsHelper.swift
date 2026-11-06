import AppKit

@MainActor
public struct PermissionsHelper {
    public static var appBundleURL: URL? {
        let fm = FileManager.default
        let sysNotch = URL(fileURLWithPath: "/Applications/Notch.app")
        if fm.fileExists(atPath: sysNotch.path) {
            return sysNotch
        }
        
        let sysApp = URL(fileURLWithPath: "/Applications/NotchApp.app")
        if fm.fileExists(atPath: sysApp.path) {
            return sysApp
        }
        
        let home = fm.homeDirectoryForCurrentUser
        let userNotch = home.appendingPathComponent("Applications/Notch.app")
        if fm.fileExists(atPath: userNotch.path) {
            return userNotch
        }
        
        let userApp = home.appendingPathComponent("Applications/NotchApp.app")
        if fm.fileExists(atPath: userApp.path) {
            return userApp
        }
        
        // Check dynamic project directory
        let projectDir = dynamicProjectDirectory
        let projApp = projectDir.appendingPathComponent("NotchApp.app")
        if fm.fileExists(atPath: projApp.path) {
            return projApp
        }
        
        if Bundle.main.bundleURL.pathExtension == "app" {
            return Bundle.main.bundleURL
        }
        return nil
    }
    
    /// Guarantees that both /Applications/Notch.app AND /Applications/NotchApp.app exist,
    /// as well as the user-level ~/Applications equivalents.
    public static func ensureApplicationsSymlink() {
        let fm = FileManager.default
        let projectDir = dynamicProjectDirectory
        let bundleURL = projectDir.appendingPathComponent("NotchApp.app")
        guard fm.fileExists(atPath: bundleURL.path) else { return }
        
        // 1. Ensure System /Applications symlinks (/Applications/Notch.app & /Applications/NotchApp.app)
        let systemTargets = [
            "/Applications/Notch.app",
            "/Applications/NotchApp.app"
        ]
        
        for sysAppPath in systemTargets {
            if let dest = try? fm.destinationOfSymbolicLink(atPath: sysAppPath) {
                if dest != bundleURL.path {
                    try? fm.removeItem(atPath: sysAppPath)
                    try? fm.createSymbolicLink(atPath: sysAppPath, withDestinationPath: bundleURL.path)
                }
            } else if !fm.fileExists(atPath: sysAppPath) {
                try? fm.createSymbolicLink(atPath: sysAppPath, withDestinationPath: bundleURL.path)
            }
        }
        
        // 2. Ensure User ~/Applications symlinks
        let home = fm.homeDirectoryForCurrentUser
        let userAppsDir = home.appendingPathComponent("Applications")
        if !fm.fileExists(atPath: userAppsDir.path) {
            try? fm.createDirectory(at: userAppsDir, withIntermediateDirectories: true)
        }
        
        let userTargets = [
            userAppsDir.appendingPathComponent("Notch.app"),
            userAppsDir.appendingPathComponent("NotchApp.app")
        ]
        
        for userApp in userTargets {
            if let dest = try? fm.destinationOfSymbolicLink(atPath: userApp.path) {
                if dest != bundleURL.path {
                    try? fm.removeItem(at: userApp)
                    try? fm.createSymbolicLink(at: userApp, withDestinationURL: bundleURL)
                }
            } else if !fm.fileExists(atPath: userApp.path) {
                try? fm.createSymbolicLink(at: userApp, withDestinationURL: bundleURL)
            }
        }
    }
    
    public static var dynamicProjectDirectory: URL {
        let rawArg = CommandLine.arguments[0]
        let argURL = URL(fileURLWithPath: rawArg).resolvingSymlinksInPath()
        
        // If run from .build/release/NotchApp, project dir is 3 levels up
        var dir = argURL.deletingLastPathComponent()
        for _ in 0..<4 {
            if FileManager.default.fileExists(atPath: dir.appendingPathComponent("Package.swift").path) {
                return dir
            }
            dir = dir.deletingLastPathComponent()
        }
        
        // Dynamic fallback to current working directory or bundle container
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    }

    public static var executableURL: URL {
        if let bundle = appBundleURL {
            return bundle
        }
        let projectDir = dynamicProjectDirectory
        let symlinkURL = projectDir.appendingPathComponent("NotchApp")
        if FileManager.default.fileExists(atPath: symlinkURL.path) {
            return symlinkURL
        }
        let releaseBin = projectDir.appendingPathComponent(".build/release/NotchApp")
        if FileManager.default.fileExists(atPath: releaseBin.path) {
            return releaseBin
        }
        return Bundle.main.executableURL ?? URL(fileURLWithPath: CommandLine.arguments[0])
    }
    
    /// Standard path to copy for Command+Shift+G
    public static var standardAppPath: String {
        let fm = FileManager.default
        if fm.fileExists(atPath: "/Applications/Notch.app") {
            return "/Applications/Notch.app"
        }
        if fm.fileExists(atPath: "/Applications/NotchApp.app") {
            return "/Applications/NotchApp.app"
        }
        return executableURL.path
    }
    
    public static func revealAppInFinder() {
        FeedbackManager.playClick()
        ensureApplicationsSymlink()
        
        let fm = FileManager.default
        let targetURL: URL
        if fm.fileExists(atPath: "/Applications/Notch.app") {
            targetURL = URL(fileURLWithPath: "/Applications/Notch.app")
        } else if fm.fileExists(atPath: "/Applications/NotchApp.app") {
            targetURL = URL(fileURLWithPath: "/Applications/NotchApp.app")
        } else {
            targetURL = executableURL
        }
        NSWorkspace.shared.activateFileViewerSelecting([targetURL])
    }
    
    public static func copyAppPathToClipboard() {
        FeedbackManager.playClick()
        let path = standardAppPath
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(path, forType: .string)
    }
    
    public static func openAccessibilitySettings() {
        FeedbackManager.playClick()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
    
    public static func openInputMonitoringSettings() {
        FeedbackManager.playClick()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEventAccess") {
            NSWorkspace.shared.open(url)
        }
    }
}
