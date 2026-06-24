import SwiftUI
import UniformTypeIdentifiers

struct PinboardTabBar: View {
    @ObservedObject var store: ClipboardStore
    @Binding var isSearching: Bool
    @Binding var showAddPinboard: Bool
    @State private var dropTargetID: UUID?

    var body: some View {
        HStack(spacing: 0) {
            // Search toggle
            Button {
                isSearching.toggle()
                if !isSearching { store.searchQuery = "" }
            } label: {
                Image(systemName: isSearching ? "xmark" : "magnifyingglass")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)

            // Tabs (scrollable)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    PinboardTab(
                        label: "Clipboard",
                        icon: "clipboard.fill",
                        color: .blue,
                        isSelected: store.selectedPinboardID == nil
                    ) { store.selectedPinboardID = nil }

                    ForEach(store.pinboards) { board in
                        PinboardTab(
                            label: board.name,
                            icon: nil,
                            color: board.color,
                            isSelected: store.selectedPinboardID == board.id
                        ) { store.selectedPinboardID = board.id }
                            .overlay(
                                Capsule().stroke(Color.white, lineWidth: dropTargetID == board.id ? 2 : 0)
                            )
                            .onDrop(of: [.text], isTargeted: Binding(
                                get: { dropTargetID == board.id },
                                set: { dropTargetID = $0 ? board.id : nil }
                            )) { providers in handleDrop(providers, board: board) }
                            .contextMenu {
                                Button("Delete \"\(board.name)\"", role: .destructive) {
                                    store.removePinboard(id: board.id)
                                }
                            }
                    }
                }
                .padding(.horizontal, 4)
            }

            Spacer()

            // Add pinboard
            Button {
                showAddPinboard = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .help("New Pinboard")

            // Settings menu
            Menu {
                Text("Shortcut: \(ShortcutManager.shared.displayString)")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Divider()
                Button("Clear All") { store.clearNonPinned() }
                Divider()
                Button("Quit OpenPasteMac") { NSApp.terminate(nil) }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 36, height: 36)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
        .frame(height: 44)
        .padding(.horizontal, 8)
    }

    private func handleDrop(_ providers: [NSItemProvider], board: Pinboard) -> Bool {
        guard let provider = providers.first else { return false }
        _ = provider.loadObject(ofClass: NSString.self) { obj, _ in
            guard let idStr = obj as? NSString else { return }
            DispatchQueue.main.async { store.addItemID(idStr as String, toPinboard: board.id) }
        }
        return true
    }
}

struct PinboardTab: View {
    let label: String
    let icon: String?
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(isSelected ? .white : color)
                } else {
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)
                }
                Text(label)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.65))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(isSelected ? Color.blue.opacity(0.75) : Color.white.opacity(0.06))
            )
        }
        .buttonStyle(.plain)
    }
}

struct AddPinboardSheet: View {
    @ObservedObject var store: ClipboardStore
    @Binding var isPresented: Bool
    @State private var name = ""
    @State private var colorHex = Pinboard.palette[0]

    var body: some View {
        VStack(spacing: 16) {
            Text("New Pinboard")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)

            TextField("Name", text: $name)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundColor(.white)
                .padding(8)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 7))

            HStack(spacing: 8) {
                ForEach(Pinboard.palette, id: \.self) { hex in
                    Circle()
                        .fill(Color(hex: hex))
                        .frame(width: 22, height: 22)
                        .overlay(
                            Circle().stroke(Color.white, lineWidth: colorHex == hex ? 2 : 0)
                        )
                        .onTapGesture { colorHex = hex }
                }
            }

            HStack {
                Button("Cancel") { isPresented = false }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Create") {
                    guard !name.isEmpty else { return }
                    store.addPinboard(name: name, colorHex: colorHex)
                    isPresented = false
                }
                .buttonStyle(.plain)
                .foregroundColor(.blue)
                .disabled(name.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 280)
        .background(Color(red: 0.13, green: 0.16, blue: 0.24))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
