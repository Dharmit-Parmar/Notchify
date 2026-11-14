import SwiftUI
import AppKit
import LocalShare

// MARK: - LocalShare Module Persistent Settings Store
public typealias LocalShareSettingsStore = LocalShareSettings

// MARK: - LocalShare Settings View (Integrated in Settings -> Tab Modules -> Advanced)
public struct LocalShareSettingsView: View {
    @ObservedObject private var settings = LocalShareSettingsStore.shared
    
    public init() {}
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header Title Card
            HStack(spacing: 8) {
                Image(systemName: "shareplay")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color(red: 0.20, green: 0.78, blue: 0.85))
                Text("Local Share Configuration")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(SettingsInk.primary)
                Spacer()
                if settings.isReceiveEnabled {
                    Text("Receiver ON")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.green)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.green.opacity(0.15)))
                } else {
                    Text("Receiver OFF")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(SettingsInk.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(SettingsInk.tint(0.08)))
                }
            }
            
            Text("Universal local network file sharing compatible with the LocalSend v2 protocol.")
                .font(.system(size: 9.5))
                .foregroundColor(SettingsInk.secondary)
            
            Divider().background(SettingsInk.tint(0.06))
            
            // 1. Device Alias
            VStack(alignment: .leading, spacing: 4) {
                Text("Device Alias")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundColor(SettingsInk.primary)
                Text("Display name visible to other devices on the local network.")
                    .font(.system(size: 9.5))
                    .foregroundColor(SettingsInk.secondary)
                
                HStack {
                    TextField("Device Alias", text: $settings.alias)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11))
                        .frame(maxWidth: 240)
                    
                    Button("Reset to Mac Name") {
                        settings.alias = Host.current().localizedName ?? "MacBook"
                    }
                    .buttonStyle(.spring)
                    .font(.system(size: 10))
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Local Share Device Alias")
            
            Divider().background(SettingsInk.tint(0.06))
            
            // 2. Receive Mode Toggle
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Receive Mode")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundColor(SettingsInk.primary)
                    Text("Start background HTTPS listener to accept incoming transfers.")
                        .font(.system(size: 9.5))
                        .foregroundColor(SettingsInk.secondary)
                }
                Spacer()
                Toggle("", isOn: $settings.isReceiveEnabled)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .labelsHidden()
                    .accessibilityLabel("Receive Mode")
                    .accessibilityHint("Turns local receiver listener ON or OFF")
            }
            
            Divider().background(SettingsInk.tint(0.06))
            
            // 3. Receive Folder
            VStack(alignment: .leading, spacing: 6) {
                Text("Receive Directory")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundColor(SettingsInk.primary)
                Text("Incoming files are stored in isolated session subdirectories here.")
                    .font(.system(size: 9.5))
                    .foregroundColor(SettingsInk.secondary)
                
                HStack(spacing: 8) {
                    Text(settings.customReceivePath.isEmpty ? "~/Downloads/LocalShare" : settings.customReceivePath)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(SettingsInk.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 6).fill(SettingsInk.tint(0.04)))
                    
                    Button("Choose Folder...") {
                        chooseCustomFolder()
                    }
                    .buttonStyle(.spring)
                    .font(.system(size: 10))
                    
                    if !settings.customReceivePath.isEmpty {
                        Button("Default") {
                            settings.customReceivePath = ""
                        }
                        .buttonStyle(.spring)
                        .font(.system(size: 10))
                    }
                }
            }
            
            Divider().background(SettingsInk.tint(0.06))
            
            // 4. Favorites & Auto-Accept
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Auto-Accept from Favorites")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundColor(SettingsInk.primary)
                        Text("Only skips the confirmation prompt for devices with explicitly verified identities.")
                            .font(.system(size: 9.5))
                            .foregroundColor(SettingsInk.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $settings.autoAcceptFavorites)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .labelsHidden()
                        .accessibilityLabel("Auto-Accept from Favorites")
                }
                
                if !settings.favoriteFingerprints.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Trusted Identity Fingerprints (\(settings.favoriteFingerprints.count)):")
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundColor(SettingsInk.secondary)
                        
                        ForEach(settings.favoriteFingerprints, id: \.self) { fp in
                            HStack {
                                Text("\(fp.prefix(12))...\(fp.suffix(8))")
                                    .font(.system(size: 9.5, design: .monospaced))
                                    .foregroundColor(SettingsInk.primary)
                                Spacer()
                                Button("Remove") {
                                    settings.removeFavorite(fingerprint: fp)
                                }
                                .buttonStyle(.spring)
                                .font(.system(size: 9))
                                .foregroundColor(.red)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(RoundedRectangle(cornerRadius: 4).fill(SettingsInk.tint(0.03)))
                        }
                    }
                } else {
                    Text("No favorite device identities saved yet. Add devices from the Local Share peer list.")
                        .font(.system(size: 9.5, design: .rounded))
                        .foregroundColor(SettingsInk.secondary)
                }
            }
            
            Divider().background(SettingsInk.tint(0.06))
            
            // 5. Transfer PIN Protection
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Transfer PIN Protection")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundColor(SettingsInk.primary)
                        Text("Require senders to enter this PIN before a transfer offer is accepted.")
                            .font(.system(size: 9.5))
                            .foregroundColor(SettingsInk.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $settings.isPinEnabled)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .labelsHidden()
                        .accessibilityLabel("Transfer PIN Protection")
                }
                
                if settings.isPinEnabled {
                    HStack {
                        SecureField("4-8 char PIN", text: $settings.pinCode)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 11, design: .monospaced))
                            .frame(maxWidth: 140)
                        Text("Must match sender's PIN input")
                            .font(.system(size: 9))
                            .foregroundColor(SettingsInk.secondary)
                    }
                }
            }
            
            Divider().background(SettingsInk.tint(0.06))
            
            // 6. Network Info & Port
            HStack {
                Text("Protocol Port:")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundColor(SettingsInk.secondary)
                Text("\(settings.tcpPort) (TCP/UDP)")
                    .font(.system(size: 9.5, design: .monospaced))
                    .foregroundColor(SettingsInk.primary)
                Spacer()
                Text("Certificate Fingerprint:")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundColor(SettingsInk.secondary)
                Text("\(LocalShareIdentityManager.shared.certificateFingerprint.prefix(8))...")
                    .font(.system(size: 9.5, design: .monospaced))
                    .foregroundColor(SettingsInk.primary)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(SettingsInk.tint(0.03)))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(SettingsInk.tint(0.08), lineWidth: 0.8))
    }
    
    private func chooseCustomFolder() {
        let panel = NSOpenPanel()
        panel.title = "Select Local Share Receive Directory"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Select Folder"
        
        if panel.runModal() == .OK, let selectedURL = panel.url {
            settings.customReceivePath = selectedURL.path
        }
    }
}
