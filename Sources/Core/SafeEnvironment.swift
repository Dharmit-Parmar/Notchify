import Foundation

/// SEC-C-1: Sanitized Process Environment Allowlist
/// Restricts environment variables passed to child processes (`git`, `cargo`, `thock-cli`)
/// to prevent leaking sensitive ambient secrets (e.g. AWS keys, GitHub tokens, API credentials).
public enum SafeEnvironment {
    /// Constructs a safe, minimal environment dictionary.
    public static func make(extra: [String: String] = [:]) -> [String: String] {
        let ambient = ProcessInfo.processInfo.environment
        var env: [String: String] = [:]
        
        let home = NSHomeDirectory()
        env["HOME"] = ambient["HOME"] ?? home
        env["USER"] = ambient["USER"] ?? NSUserName()
        env["LANG"] = ambient["LANG"] ?? "en_US.UTF-8"
        env["TERM"] = ambient["TERM"] ?? "xterm-256color"
        
        // Comprehensive system & toolchain PATH
        let standardPaths = [
            URL(fileURLWithPath: home).appendingPathComponent(".cargo/bin").path,
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin"
        ]
        let ambientPath = ambient["PATH"] ?? ""
        var pathComponents = standardPaths
        if !ambientPath.isEmpty {
            for comp in ambientPath.components(separatedBy: ":") where !comp.isEmpty {
                if !pathComponents.contains(comp) {
                    pathComponents.append(comp)
                }
            }
        }
        env["PATH"] = pathComponents.joined(separator: ":")
        
        // Pass toolchain directories only if explicitly set in ambient environment
        if let cargoHome = ambient["CARGO_HOME"], !cargoHome.isEmpty {
            env["CARGO_HOME"] = cargoHome
        }
        if let rustupHome = ambient["RUSTUP_HOME"], !rustupHome.isEmpty {
            env["RUSTUP_HOME"] = rustupHome
        }
        
        // Caller-specific overrides (e.g. TERM or custom variables)
        for (k, v) in extra {
            env[k] = v
        }
        
        return env
    }
}
