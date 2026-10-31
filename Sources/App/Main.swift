import AppKit

@main
struct MainApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory) // Runs as a clean menu bar / notch accessory without dock icon
        app.run()
    }
}
