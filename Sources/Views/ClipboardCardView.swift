import SwiftUI
import AppKit

struct ClipboardCardView: View {
    let item: ClipboardItem
    let index: Int
    let isSelected: Bool
    let frontAppName: String?
    var onPaste: () -> Void
    var onPastePlainText: () -> Void
    var onCopyOnly: () -> Void
    var onEdit: () -> Void
    var onRename: () -> Void
    var onPreview: () -> Void
    var onPin: () -> Void
    var onDelete: () -> Void
    var onAddToPinboard: (Pinboard) -> Void
    var onCreatePinboard: () -> Void
    let pinboards: [Pinboard]

    @State private var isHovered = false

    static let cardWidth:  CGFloat = 210
    static let cardHeight: CGFloat = 220

    var body: some View {
        VStack(spacing: 0) {
            cardHeader
            cardBody
            cardFooter
        }
        .frame(width: Self.cardWidth, height: Self.cardHeight)
        .background(Color(red: 0.09, green: 0.115, blue: 0.18))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(
                    isSelected ? Color(red: 0.22, green: 0.55, blue: 1.0) : Color.white.opacity(0.08),
                    lineWidth: isSelected ? 2.5 : 0.5
                )
        )
        .shadow(color: .black.opacity(isSelected ? 0.6 : 0.35), radius: isSelected ? 12 : 6, y: 4)
        .scaleEffect(isSelected ? 1.02 : (isHovered ? 1.01 : 1.0))
        .animation(.spring(response: 0.32, dampingFraction: 0.72), value: isSelected)
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .onHover { isHovered = $0 }
        .onDrag { NSItemProvider(object: item.id.uuidString as NSString) }
        .onTapGesture { onPaste() }
        .contextMenu { contextMenu }
    }

    // MARK: - Header

    private var cardHeader: some View {
        HStack(alignment: .top, spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                // Show user label if set, else type name
                Text(item.label ?? item.content.typeLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(item.timeAgo)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.65))
            }
            Spacer()
            appIconView
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(item.content.headerColor)
    }

    @ViewBuilder
    private var appIconView: some View {
        if let nsImage = item.sourceApp?.icon {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 26, height: 26)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        } else {
            Image(systemName: "app.dashed")
                .font(.system(size: 18))
                .foregroundColor(.white.opacity(0.25))
                .frame(width: 26, height: 26)
        }
    }

    // MARK: - Body

    @ViewBuilder
    private var cardBody: some View {
        switch item.content {
        case .text(let str):   textBody(str)
        case .url(let url):    linkBody(url)
        case .image(let img):  imageBody(img)
        case .file(let url):   fileBody(url)
        }
    }

    private func textBody(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11.5))
            .foregroundColor(.white.opacity(0.85))
            .lineLimit(6)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
    }

    private func linkBody(_ url: URL) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let meta = item.linkMetadata {
                HStack(spacing: 8) {
                    Group {
                        if let favicon = meta.favicon {
                            Image(nsImage: favicon)
                                .resizable()
                                .frame(width: 18, height: 18)
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                        } else {
                            Image(systemName: "globe")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.35))
                        }
                    }
                    Text(meta.domain ?? url.host ?? "")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.45))
                        .lineLimit(1)
                }
                if let preview = meta.previewImage {
                    Image(nsImage: preview)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity).frame(height: 68)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                if let title = meta.title {
                    Text(title)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(2)
                }
            } else {
                Image(systemName: "link")
                    .font(.system(size: 22))
                    .foregroundColor(.white.opacity(0.2))
                Text(url.host?.replacingOccurrences(of: "www.", with: "") ?? "")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.4))
                Text(url.absoluteString)
                    .font(.system(size: 10.5))
                    .foregroundColor(.white.opacity(0.65))
                    .lineLimit(3)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private func imageBody(_ image: NSImage) -> some View {
        Image(nsImage: image)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
    }

    private func fileBody(_ url: URL) -> some View {
        VStack(spacing: 8) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable().frame(width: 44, height: 44)
            Text(url.lastPathComponent)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(10)
    }

    // MARK: - Footer

    private var cardFooter: some View {
        HStack {
            Text(item.footerLabel)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.white.opacity(0.3))
                .lineLimit(1)
            Spacer()
            HStack(spacing: 3) {
                Image(systemName: "text.justify")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.22))
                Text("\(index + 1)")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(isSelected ? 0.9 : 0.3))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.2))
    }

    // MARK: - Context Menu

    @ViewBuilder
    private var contextMenu: some View {
        // ── Paste actions ─────────────────────────────────────────
        if let appName = frontAppName {
            Button {
                onPaste()
            } label: {
                Label("Paste to \(appName)", systemImage: "doc.on.doc")
            }
        } else {
            Button {
                onPaste()
            } label: {
                Label("Paste", systemImage: "doc.on.doc")
            }
        }

        Button {
            onPastePlainText()
        } label: {
            Label("Paste as Plain Text", systemImage: "text.alignleft")
        }

        Button {
            onCopyOnly()
        } label: {
            Label("Copy", systemImage: "doc.on.clipboard")
        }

        Divider()

        // ── Edit / Rename ─────────────────────────────────────────
        if case .text = item.content {
            Button {
                onEdit()
            } label: {
                Label("Edit", systemImage: "pencil")
            }
        }

        Button {
            onRename()
        } label: {
            Label("Rename", systemImage: "pencil.line")
        }

        Button(role: .destructive) {
            onDelete()
        } label: {
            Label("Delete", systemImage: "trash")
        }

        Divider()

        // ── Pin submenu ────────────────────────────────────────────
        Menu {
            if pinboards.isEmpty {
                Text("No pinboards yet")
                    .foregroundColor(.secondary)
            } else {
                ForEach(pinboards) { board in
                    Button {
                        onAddToPinboard(board)
                    } label: {
                        HStack {
                            Image(systemName: "circle.fill")
                                .foregroundColor(board.color)
                            Text(board.name)
                        }
                    }
                }
                Divider()
            }
            Button("Create Pinboard...") { onCreatePinboard() }
        } label: {
            Label(item.isPinned ? "Pin (Pinned)" : "Pin", systemImage: "pin")
        }

        Divider()

        // ── Preview / Share ────────────────────────────────────────
        Button {
            onPreview()
        } label: {
            Label("Preview", systemImage: "eye")
        }

        Button {
            showSharePicker()
        } label: {
            Label("Share", systemImage: "square.and.arrow.up")
        }
    }

    // MARK: - Sharing

    private func showSharePicker() {
        let items: [Any]
        switch item.content {
        case .text(let t):    items = [t]
        case .url(let u):     items = [u]
        case .image(let img): items = [img]
        case .file(let u):    items = [u]
        }
        let picker = NSSharingServicePicker(items: items)
        // Anchor to the panel's content view
        if let view = NSApp.keyWindow?.contentView {
            let origin = NSPoint(x: view.bounds.midX, y: view.bounds.midY)
            picker.show(relativeTo: NSRect(origin: origin, size: .zero), of: view, preferredEdge: .minY)
        }
    }
}
