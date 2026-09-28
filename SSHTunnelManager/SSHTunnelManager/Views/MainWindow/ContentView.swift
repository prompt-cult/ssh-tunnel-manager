import SwiftUI
import ServiceManagement
import os

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "SSHTunnelManager",
    category: "ContentView"
)

@MainActor
struct ContentView: View {
    @Environment(TunnelManager.self) private var tunnelManager
    @State private var selectedID: UUID?
    @State private var showPreferences = false

    private var selectedItem: SidebarItem? {
        guard let id = selectedID else { return nil }
        return tunnelManager.items.first { $0.id == id }
    }

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                TunnelListView(selection: $selectedID)

                Divider()

                // Action bar for the selected item (tunnel or divider)
                if let item = selectedItem {
                    HStack(spacing: 12) {
                        Button {
                            tunnelManager.moveItemUp(id: item.id)
                        } label: {
                            Image(systemName: "arrow.up")
                        }
                        .disabled(!tunnelManager.canMoveUp(id: item.id))
                        .help("Move Up")

                        Button {
                            tunnelManager.moveItemDown(id: item.id)
                        } label: {
                            Image(systemName: "arrow.down")
                        }
                        .disabled(!tunnelManager.canMoveDown(id: item.id))
                        .help("Move Down")

                        Divider()
                            .frame(height: 16)

                        if case .tunnel(let tunnel) = item {
                            Button {
                                let clone = tunnelManager.cloneTunnel(tunnel)
                                selectedID = clone.id
                            } label: {
                                Image(systemName: "doc.on.doc")
                            }
                            .help("Clone")
                        }

                        Spacer()

                        Button(role: .destructive) {
                            deleteSelected(item)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .help("Delete")
                    }
                    .buttonStyle(.borderless)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)

                    Divider()
                }

                HStack {
                    Button {
                        showPreferences.toggle()
                    } label: {
                        Label("Preferences", systemImage: "gearshape")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .popover(isPresented: $showPreferences, arrowEdge: .bottom) {
                        AppPreferencesView {
                            showPreferences = false
                        }
                    }

                    Spacer()

                    if let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
                        Text("v\(version)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 350)
        } detail: {
            if let item = selectedItem {
                switch item {
                case .tunnel(let tunnel):
                    TunnelDetailView(tunnel: tunnel)
                case .divider(let divider):
                    DividerDetailView(divider: divider)
                        .id(divider.id)
                }
            } else {
                ContentUnavailableView {
                    Label("Nothing Selected", systemImage: "point.3.connected.trianglepath.dotted")
                } description: {
                    Text("Select a tunnel or divider from the sidebar, or create a new one.")
                } actions: {
                    Button("Add Tunnel") {
                        tunnelManager.addTunnel()
                        selectedID = tunnelManager.tunnels.last?.id
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    private func deleteSelected(_ item: SidebarItem) {
        selectedID = nil
        switch item {
        case .tunnel(let tunnel):
            tunnelManager.deleteTunnel(tunnel)
        case .divider(let divider):
            tunnelManager.deleteDivider(divider.id)
        }
    }
}

/// Detail pane for a group divider — a single name field with the same
/// focus/auto-save behavior as the tunnel editor.
@MainActor
struct DividerDetailView: View {
    let divider: GroupDivider
    @Environment(TunnelManager.self) private var tunnelManager
    @FocusState private var focused: Bool
    @State private var name: String

    init(divider: GroupDivider) {
        self.divider = divider
        self._name = State(initialValue: divider.title)
    }

    var body: some View {
        Form {
            Section {
                TextField("Group name", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .focused($focused)
                    .onSubmit { save() }
            } header: {
                Text("Group")
            } footer: {
                Text("Shown as a divider in the sidebar and as a section with a master toggle in the menu bar. Leave empty for an unnamed divider.")
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .onChange(of: focused) { _, isFocused in
            // Auto-save when the field loses focus.
            if !isFocused { save() }
        }
        .onChange(of: divider) { _, newValue in
            // A different divider was selected — load its name.
            name = newValue.title
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Save") { save() }
                    .disabled(name == divider.title)
            }
        }
    }

    private func save() {
        guard name != divider.title else { return }
        tunnelManager.renameDivider(divider.id, title: name)
    }
}

/// App-level preferences shown in a popover from the sidebar footer.
@MainActor
struct AppPreferencesView: View {
    var onDismiss: (() -> Void)? = nil

    var body: some View {
        PreferencesWindowView(onDismiss: onDismiss)
    }
}

#Preview {
    ContentView()
        .environment(TunnelManager())
}
