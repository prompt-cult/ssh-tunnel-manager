import SwiftUI
import ServiceManagement
import os

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "SSHTunnelManager",
    category: "PreferencesWindowView"
)

@MainActor
struct PreferencesWindowView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft = PreferencesDraft()

    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var soundsEnabled = TunnelSound.isEnabled
    @State private var notificationsEnabled = TunnelNotification.isEnabled

    @State private var servicePortText: String = ""
    @State private var maxPortText: String = ""

    var onDismiss: (() -> Void)? = nil

    /// Both fields stay visibly invalid (red border + caption) and Save stays
    /// disabled until the parsed values are in range, so a rejected keystroke
    /// can never be silently replaced by a stale draft value on Save.
    private var servicePortValid: Bool {
        guard let val = Int(servicePortText) else { return false }
        return val >= AppPreferences.minPort && val <= AppPreferences.maxPort
    }

    private var maxPortValid: Bool {
        guard let val = Int(maxPortText) else { return false }
        return val >= AppPreferences.minPort && val <= AppPreferences.maxPort
    }

    private var allInputsValid: Bool {
        servicePortValid && maxPortValid
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Preferences")
                .font(.headline)
                .padding(.bottom, 2)

            // Group 1: Launch at login
            Toggle("Launch at Login", isOn: $launchAtLogin)
                .toggleStyle(.checkbox)

            Divider()

            // Group 2: Sounds and Notifications
            Toggle("Play a sound on connect / disconnect", isOn: $soundsEnabled)
                .toggleStyle(.checkbox)

            Toggle("Show a notification on connect / disconnect", isOn: $notificationsEnabled)
                .toggleStyle(.checkbox)

            Divider()

            // Group 3: Port Frontier Allocation
            Toggle("Find next high port", isOn: $draft.findNextHighPort)
                .toggleStyle(.checkbox)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Default Service Port")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("4096", text: $servicePortText)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(servicePortValid ? Color.clear : Color.red,
                                            lineWidth: 1.5)
                            )
                            .onChange(of: servicePortText) { _, newValue in
                                guard let val = Int(newValue),
                                      val >= AppPreferences.minPort && val <= AppPreferences.maxPort
                                else { return }
                                draft.updateDefaultServicePort(val)
                                if draft.isLocked {
                                    maxPortText = String(draft.maxAllocatedPort)
                                }
                            }
                    }

                    Button {
                        draft.toggleLock()
                        servicePortText = String(draft.defaultServicePort)
                        maxPortText = String(draft.maxAllocatedPort)
                    } label: {
                        Image(systemName: draft.isLocked ? "link" : "link.slash")
                            .foregroundStyle(draft.isLocked ? Color.accentColor : Color.secondary)
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .help(draft.isLocked ? "Ports are linked (lock-step). Click to edit independently." : "Ports are unlinked. Click to link.")
                    .padding(.top, 14)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("High Port Frontier")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("4096", text: $maxPortText)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(maxPortValid ? Color.clear : Color.red,
                                            lineWidth: 1.5)
                            )
                            .onChange(of: maxPortText) { _, newValue in
                                guard let val = Int(newValue),
                                      val >= AppPreferences.minPort && val <= AppPreferences.maxPort
                                else { return }
                                draft.updateMaxAllocatedPort(val)
                                if draft.isLocked {
                                    servicePortText = String(draft.defaultServicePort)
                                }
                            }
                    }
                }

                if !allInputsValid {
                    Text("Ports must be integers between \(AppPreferences.minPort) and \(AppPreferences.maxPort).")
                        .font(.caption)
                        .foregroundStyle(.red)
                } else {
                    Text("New tunnels allocate local ports starting above the frontier.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            // Footer actions: Cancel and Save
            HStack {
                Button("Cancel") {
                    close()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Save") {
                    saveAndClose()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!allInputsValid)
            }
            .padding(.top, 4)
        }
        .padding(16)
        .frame(minWidth: 340, maxWidth: 420)
        .onAppear {
            servicePortText = String(draft.defaultServicePort)
            maxPortText = String(draft.maxAllocatedPort)
        }
    }

    private func saveAndClose() {
        guard allInputsValid else { return }

        if launchAtLogin != (SMAppService.mainApp.status == .enabled) {
            do {
                if launchAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                logger.error("Failed to update login item: \(error.localizedDescription, privacy: .public)")
            }
        }

        TunnelSound.isEnabled = soundsEnabled
        TunnelNotification.isEnabled = notificationsEnabled
        if notificationsEnabled {
            TunnelNotification.requestAuthorizationIfNeeded()
        }

        draft.commit()
        close()
    }

    private func close() {
        // First-run setup is "completed or dismissed" on every close path, so
        // Cancel (or Esc) can never re-trigger the first-run dialog forever.
        AppPreferences.hasCompletedFirstLaunch = true

        if let onDismiss {
            onDismiss()
        } else {
            dismiss()
        }
    }
}
