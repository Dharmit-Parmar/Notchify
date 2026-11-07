import AppKit

@main
@MainActor
struct MainApp {
    private static var appDelegate: AppDelegate?
    private static var sigtermSource: (any DispatchSourceSignal)?
    private static var sigintSource: (any DispatchSourceSignal)?

    static func main() {
        // Prevent default terminating behavior so DispatchSource signal handlers can cleanly perform teardown
        signal(SIGTERM, SIG_IGN)
        signal(SIGINT, SIG_IGN)
        
        let termSource = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
        termSource.setEventHandler {
            AppDelegate.performCleanShutdown(exitCode: 0, fromSignal: true)
        }
        termSource.resume()
        sigtermSource = termSource
        
        let intSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
        intSource.setEventHandler {
            AppDelegate.performCleanShutdown(exitCode: 0, fromSignal: true)
        }
        intSource.resume()
        sigintSource = intSource

        let app = NSApplication.shared
        let delegate = AppDelegate()
        self.appDelegate = delegate
        app.delegate = delegate
        app.setActivationPolicy(.accessory) // Runs as a clean menu bar / notch accessory without dock icon
        app.run()
    }
}
