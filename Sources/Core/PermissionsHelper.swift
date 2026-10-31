import AppKit

@MainActor
public struct PermissionsHelper {
    public static var appBundleURL: URL? {
        let fm = FileManager.default
        let sysApp = URL(fileURLWithPath: "/Applications/NotchApp.app")
        if fm.fileExists(atPath: sysApp.path) {
            return sysApp
        }
        
        let home = fm.homeDirectoryForCurrentUser
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
    
    public static func ensureApplicationsSymlink() {
        let fm = FileManager.default
        let projectDir = dynamicProjectDirectory
        let bundleURL = projectDir.appendingPathComponent("NotchApp.app")
        guard fm.fileExists(atPath: bundleURL.path) else { return }
        
        let sysAppPath = "/Applications/NotchApp.app"
        if !fm.fileExists(atPath: sysAppPath) {
            try? fm.createSymbolicLink(atPath: sysAppPath, withDestinationPath: bundleURL.path)
        }
        
        let home = fm.homeDirectoryForCurrentUser
        let userAppsDir = home.appendingPathComponent("Applications")
        if !fm.fileExists(atPath: userAppsDir.path) {
            try? fm.createDirectory(at: userAppsDir, withIntermediateDirectories: true)
        }
        let userApp = userAppsDir.appendingPathComponent("NotchApp.app")
        if !fm.fileExists(atPath: userApp.path) {
            try? fm.createSymbolicLink(at: userApp, withDestinationURL: bundleURL)
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
        
        // Standard fallback to known workspace
        return URL(fileURLWithPath: "/Users/dharmitparmar/Doc/Notch")
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
    
    public static func revealAppInFinder() {
        FeedbackManager.playClick()
        let url = executableURL
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
    
    public static func copyAppPathToClipboard() {
        FeedbackManager.playClick()
        let url = executableURL
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.path, forType: .string)
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
