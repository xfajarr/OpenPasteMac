import Foundation
import Combine

class ClipboardStore: ObservableObject {
    @Published var items: [ClipboardItem] = []
    @Published var pinboards: [Pinboard] = []
    @Published var selectedPinboardID: UUID? = nil   // nil = "Clipboard" (all)
    @Published var selectedIndex: Int = 0
    @Published var triggerFocus: Bool = false
    @Published var isSearching: Bool = false
    @Published var previousFrontApp: SourceApp? = nil   // app active before shelf opened

    @Published var searchQuery: String = "" {
        didSet { clampSelection() }
    }

    private let maxItems = 200

    // MARK: - Computed

    var filteredItems: [ClipboardItem] {
        let base: [ClipboardItem]
        if let boardID = selectedPinboardID,
           let board = pinboards.first(where: { $0.id == boardID }) {
            let ids = Set(board.itemIDs)
            base = items.filter { ids.contains($0.id.uuidString) }
        } else {
            base = items
        }
        guard !searchQuery.isEmpty else { return base }
        return base.filter { $0.content.displayText.localizedCaseInsensitiveContains(searchQuery) }
    }

    var selectedItem: ClipboardItem? { filteredItems[safe: selectedIndex] }

    // MARK: - Items

    func add(_ item: ClipboardItem) {
        items.removeAll { $0.content == item.content }
        items.insert(item, at: 0)
        if items.count > maxItems { items = Array(items.prefix(maxItems)) }
        selectedIndex = 0
        saveToDisk()

        if case .url(let url) = item.content {
            Task { await fetchLinkMetadata(itemID: item.id, url: url) }
        }
    }

    func clearNonPinned() {
        items.removeAll { !$0.isPinned }
        selectedIndex = 0
        saveToDisk()
    }

    func togglePin(item: ClipboardItem) {
        guard let i = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[i].isPinned.toggle()
        saveToDisk()
    }

    func delete(item: ClipboardItem) {
        items.removeAll { $0.id == item.id }
        for i in pinboards.indices { pinboards[i].itemIDs.removeAll { $0 == item.id.uuidString } }
        clampSelection()
        saveToDisk()
    }

    func updateLinkMetadata(id: UUID, metadata: LinkMetadata) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        items[i].linkMetadata = metadata
    }

    func updateContent(item: ClipboardItem, text: String) {
        guard let i = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[i].content = .text(text)
        saveToDisk()
    }

    func updateLabel(item: ClipboardItem, label: String?) {
        guard let i = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[i].label = label
        saveToDisk()
    }

    // MARK: - Navigation

    func moveLeft()  { selectedIndex = max(0, selectedIndex - 1) }
    func moveRight() { selectedIndex = min(filteredItems.count - 1, selectedIndex + 1) }

    private func clampSelection() {
        let count = filteredItems.count
        if selectedIndex >= count { selectedIndex = max(0, count - 1) }
    }

    // MARK: - Pinboards

    func addPinboard(name: String, colorHex: String) {
        pinboards.append(Pinboard(name: name, colorHex: colorHex))
        saveToDisk()
    }

    func removePinboard(id: UUID) {
        pinboards.removeAll { $0.id == id }
        if selectedPinboardID == id { selectedPinboardID = nil }
        saveToDisk()
    }

    func addItem(_ item: ClipboardItem, toPinboard boardID: UUID) {
        addItemID(item.id.uuidString, toPinboard: boardID)
    }

    // Used by drag-and-drop, where only the dragged item's UUID string is available.
    func addItemID(_ idStr: String, toPinboard boardID: UUID) {
        guard let i = pinboards.firstIndex(where: { $0.id == boardID }),
              items.contains(where: { $0.id.uuidString == idStr }) else { return }
        if !pinboards[i].itemIDs.contains(idStr) { pinboards[i].itemIDs.append(idStr) }
        saveToDisk()
    }

    func removeItem(_ item: ClipboardItem, fromPinboard boardID: UUID) {
        guard let i = pinboards.firstIndex(where: { $0.id == boardID }) else { return }
        pinboards[i].itemIDs.removeAll { $0 == item.id.uuidString }
        saveToDisk()
    }

    // MARK: - Async link fetch

    @MainActor
    private func fetchLinkMetadata(itemID: UUID, url: URL) async {
        let meta = await LinkPreviewService.shared.fetch(for: url)
        updateLinkMetadata(id: itemID, metadata: meta)
    }

    // MARK: - Persistence

    private let storageURL: URL = {
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("OpenPasteMac", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("store.json")
    }()

    init() { loadFromDisk() }

    private struct Store: Codable {
        var items: [PersistedItem]
        var pinboards: [Pinboard]
    }

    private struct PersistedItem: Codable {
        let id: String; let timestamp: Date
        let type: String; let value: String
        let isPinned: Bool; let label: String?
        let sourceAppName: String?; let sourceAppBundleId: String?
        let linkTitle: String?; let linkDomain: String?
    }

    func saveToDisk() {
        let persisted: [PersistedItem] = items.prefix(100).compactMap { item in
            switch item.content {
            case .text(let t):
                return PersistedItem(id: item.id.uuidString, timestamp: item.timestamp,
                                     type: "text", value: t, isPinned: item.isPinned, label: item.label,
                                     sourceAppName: item.sourceApp?.name, sourceAppBundleId: item.sourceApp?.bundleIdentifier,
                                     linkTitle: nil, linkDomain: nil)
            case .url(let u):
                return PersistedItem(id: item.id.uuidString, timestamp: item.timestamp,
                                     type: "url", value: u.absoluteString, isPinned: item.isPinned, label: item.label,
                                     sourceAppName: item.sourceApp?.name, sourceAppBundleId: item.sourceApp?.bundleIdentifier,
                                     linkTitle: item.linkMetadata?.title, linkDomain: item.linkMetadata?.domain)
            default: return nil
            }
        }
        let store = Store(items: persisted, pinboards: pinboards)
        if let data = try? JSONEncoder().encode(store) { try? data.write(to: storageURL) }
    }

    private func loadFromDisk() {
        guard let data = try? Data(contentsOf: storageURL),
              let store = try? JSONDecoder().decode(Store.self, from: data) else { return }

        items = store.items.compactMap { p -> ClipboardItem? in
            guard let uuid = UUID(uuidString: p.id) else { return nil }
            let content: ClipboardItem.Content
            switch p.type {
            case "url":
                guard let url = URL(string: p.value) else { return nil }
                content = .url(url)
            default:
                content = .text(p.value)
            }
            let src = p.sourceAppName.map { SourceApp(name: $0, bundleIdentifier: p.sourceAppBundleId) }
            var item = ClipboardItem(id: uuid, timestamp: p.timestamp, content: content,
                                     isPinned: p.isPinned, sourceApp: src, label: p.label)
            if p.type == "url" { item.linkMetadata = LinkMetadata(title: p.linkTitle, domain: p.linkDomain) }
            return item
        }
        pinboards = store.pinboards
    }
}
