import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct RichInputBar: View {
    @Bindable var state: RichInputState
    let paneID: UUID
    let onDismiss: () -> Void
    let onSubmit: () -> Void

    @State private var editorContentHeight: CGFloat = 0

    private static let editorVerticalInset: CGFloat = 4
    private static let editorMaxLines: Int = 10

    private var editorLineHeight: CGFloat {
        let font = NSFont.systemFont(ofSize: 13)
        return NSLayoutManager().defaultLineHeight(for: font)
    }

    private var editorMinHeight: CGFloat {
        ceil(editorLineHeight + Self.editorVerticalInset * 2)
    }

    private var editorMaxHeight: CGFloat {
        ceil(editorLineHeight * CGFloat(Self.editorMaxLines) + Self.editorVerticalInset * 2)
    }

    private var clampedEditorHeight: CGFloat {
        min(max(editorContentHeight, editorMinHeight), editorMaxHeight)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle().fill(MuxyTheme.border).frame(height: 1)

            VStack(alignment: .leading, spacing: 6) {
                if !state.attachments.isEmpty {
                    AttachmentChipsView(
                        attachments: state.attachments,
                        onRemove: { url in
                            state.attachments.removeAll { $0 == url }
                        }
                    )
                }

                RichInputEditor(
                    text: $state.text,
                    focusVersion: state.focusVersion,
                    onSubmit: { onSubmit() },
                    onAttachImage: { url in
                        state.attachments.append(url)
                    },
                    onAttachFileURL: { url in
                        state.attachments.append(url)
                    },
                    onContentHeightChange: { height in
                        editorContentHeight = height
                    }
                )
                .frame(height: clampedEditorHeight)

                HStack(spacing: 6) {
                    Button(action: pickAttachment) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .buttonStyle(RichInputToolbarButtonStyle())
                    .accessibilityLabel("Add attachment")
                    .help("Add attachment")

                    if let agentName = state.detectedAgentName {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 9, weight: .semibold))
                            Text(agentName)
                                .font(.system(size: 10, weight: .medium))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .foregroundStyle(MuxyTheme.accent)
                        .background(MuxyTheme.accentSoft)
                        .clipShape(Capsule())
                    }

                    Spacer()

                    Button(action: onDismiss) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 9, weight: .semibold))
                            Text("Hide")
                                .font(.system(size: 11, weight: .medium))
                        }
                    }
                    .buttonStyle(RichInputToolbarButtonStyle())
                    .accessibilityLabel("Hide Rich Input")

                    Button(action: onSubmit) {
                        HStack(spacing: 4) {
                            Text("Send")
                                .font(.system(size: 11, weight: .semibold))
                            Image(systemName: "return")
                                .font(.system(size: 9, weight: .semibold))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                    .background(MuxyTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                    .keyboardShortcut(.defaultAction)
                    .accessibilityLabel("Send")
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .background(MuxyTheme.bg)
        .onDrop(of: [UTType.fileURL, UTType.image], isTargeted: nil) { providers in
            handleDrop(providers: providers)
        }
    }

    private func pickAttachment() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = true
        panel.message = "Select files or folders to attach"
        guard panel.runModal() == .OK else { return }
        for url in panel.urls where !state.attachments.contains(url) {
            state.attachments.append(url)
        }
        state.focusVersion += 1
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        var consumed = false
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    let url: URL? = if let url = item as? URL {
                        url
                    } else if let data = item as? Data {
                        URL(dataRepresentation: data, relativeTo: nil)
                    } else {
                        nil
                    }
                    guard let url else { return }
                    Task { @MainActor in
                        if !state.attachments.contains(url) {
                            state.attachments.append(url)
                        }
                    }
                }
                consumed = true
                continue
            }
            if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                    guard let data else { return }
                    let url = RichInputTempFiles.write(imageData: data)
                    guard let url else { return }
                    Task { @MainActor in
                        state.attachments.append(url)
                    }
                }
                consumed = true
            }
        }
        return consumed
    }
}

private struct AttachmentChipsView: View {
    let attachments: [URL]
    let onRemove: (URL) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(attachments, id: \.self) { url in
                    AttachmentChip(url: url, onRemove: { onRemove(url) })
                }
            }
        }
    }
}

private struct AttachmentChip: View {
    let url: URL
    let onRemove: () -> Void

    private var isImage: Bool {
        guard let utType = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType else {
            return false
        }
        return utType.conforms(to: .image)
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: isImage ? "photo" : "doc")
                .font(.system(size: 10))
                .foregroundStyle(MuxyTheme.fgMuted)
            Text(url.lastPathComponent)
                .font(.system(size: 11))
                .foregroundStyle(MuxyTheme.fg)
                .lineLimit(1)
                .truncationMode(.middle)
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(MuxyTheme.fgMuted)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove attachment")
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(MuxyTheme.surface)
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(MuxyTheme.border, lineWidth: 1))
    }
}

private struct RichInputEditor: NSViewRepresentable {
    @Binding var text: String
    let focusVersion: Int
    let onSubmit: () -> Void
    let onAttachImage: (URL) -> Void
    let onAttachFileURL: (URL) -> Void
    let onContentHeightChange: (CGFloat) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.autohidesScrollers = true
        scrollView.contentView.drawsBackground = false

        let textContainer = NSTextContainer(containerSize: NSSize(
            width: 0,
            height: CGFloat.greatestFiniteMagnitude
        ))
        textContainer.widthTracksTextView = true
        textContainer.lineFragmentPadding = 0

        let layoutManager = NSLayoutManager()
        layoutManager.addTextContainer(textContainer)

        let textStorage = NSTextStorage()
        textStorage.addLayoutManager(layoutManager)

        let textView = RichInputTextView(
            frame: NSRect(origin: .zero, size: scrollView.contentSize),
            textContainer: textContainer
        )
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainerInset = NSSize(width: 0, height: 4)
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = false
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticTextCompletionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.smartInsertDeleteEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.font = NSFont.systemFont(ofSize: 13)
        textView.textColor = MuxyTheme.snapshotForeground()
        textView.insertionPointColor = MuxyTheme.snapshotForeground()
        textView.delegate = context.coordinator
        textView.onSubmit = { [weak coordinator = context.coordinator] in
            coordinator?.parent.onSubmit()
        }
        textView.onAttachImage = { [weak coordinator = context.coordinator] url in
            coordinator?.parent.onAttachImage(url)
        }
        textView.onAttachFileURL = { [weak coordinator = context.coordinator] url in
            coordinator?.parent.onAttachFileURL(url)
        }

        if textView.string != text {
            textView.string = text
        }

        textView.pendingFocusGrab = true
        scrollView.documentView = textView
        context.coordinator.textView = textView
        context.coordinator.lastFocusVersion = focusVersion
        DispatchQueue.main.async { [weak coordinator = context.coordinator] in
            coordinator?.reportContentHeight()
        }
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? RichInputTextView else { return }
        context.coordinator.parent = self
        if textView.string != text {
            textView.string = text
        }
        textView.textColor = MuxyTheme.snapshotForeground()
        textView.insertionPointColor = MuxyTheme.snapshotForeground()
        if context.coordinator.lastFocusVersion != focusVersion {
            context.coordinator.lastFocusVersion = focusVersion
            textView.grabFirstResponder()
        }
        DispatchQueue.main.async { [weak coordinator = context.coordinator] in
            coordinator?.reportContentHeight()
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: RichInputEditor
        weak var textView: RichInputTextView?
        var lastFocusVersion: Int = -1
        private var lastReportedHeight: CGFloat = -1

        init(parent: RichInputEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            reportContentHeight()
        }

        func reportContentHeight() {
            guard let textView,
                  let layoutManager = textView.layoutManager,
                  let textContainer = textView.textContainer
            else { return }
            layoutManager.ensureLayout(for: textContainer)
            let usedRect = layoutManager.usedRect(for: textContainer)
            let inset = textView.textContainerInset.height
            let height = ceil(usedRect.height + inset * 2)
            guard abs(height - lastReportedHeight) > 0.5 else { return }
            lastReportedHeight = height
            parent.onContentHeightChange(height)
        }

        func textView(
            _ textView: NSTextView,
            doCommandBy commandSelector: Selector
        ) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                let event = NSApp.currentEvent
                let isShift = event?.modifierFlags.contains(.shift) ?? false
                if isShift {
                    textView.insertNewlineIgnoringFieldEditor(nil)
                    return true
                }
                parent.onSubmit()
                return true
            }
            return false
        }
    }
}

private final class RichInputTextView: NSTextView {
    var onSubmit: (() -> Void)?
    var onAttachImage: ((URL) -> Void)?
    var onAttachFileURL: ((URL) -> Void)?
    var pendingFocusGrab: Bool = false

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard pendingFocusGrab else { return }
        pendingFocusGrab = false
        grabFirstResponder()
    }

    func grabFirstResponder() {
        guard let window else {
            pendingFocusGrab = true
            return
        }
        DispatchQueue.main.async { [weak self, weak window] in
            guard let self, let window else { return }
            window.makeFirstResponder(self)
        }
    }

    override func paste(_ sender: Any?) {
        let pasteboard = NSPasteboard.general
        if pasteboard.canReadObject(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]),
           let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL]
        {
            for url in urls {
                onAttachFileURL?(url)
            }
            if !urls.isEmpty { return }
        }
        if pasteboard.string(forType: .string) == nil,
           pasteboard.canReadObject(forClasses: [NSImage.self], options: nil),
           let imageData = readImageData(from: pasteboard),
           let url = RichInputTempFiles.write(imageData: imageData)
        {
            onAttachImage?(url)
            return
        }
        pasteAsPlainText(sender)
    }

    private func readImageData(from pasteboard: NSPasteboard) -> Data? {
        if let data = pasteboard.data(forType: .png) { return data }
        if let data = pasteboard.data(forType: .tiff) { return data }
        if let image = NSImage(pasteboard: pasteboard), let data = image.tiffRepresentation {
            return data
        }
        return nil
    }

    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        let pasteboard = sender.draggingPasteboard
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], !urls.isEmpty {
            for url in urls {
                onAttachFileURL?(url)
            }
            return true
        }
        if let image = NSImage(pasteboard: pasteboard),
           let data = image.tiffRepresentation,
           let url = RichInputTempFiles.write(imageData: data)
        {
            onAttachImage?(url)
            return true
        }
        return super.performDragOperation(sender)
    }
}

enum RichInputTempFiles {
    static let directoryName = "Muxy/RichInput"

    static func directoryURL() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("Muxy", isDirectory: true)
            .appendingPathComponent("RichInput", isDirectory: true)
    }

    static func write(imageData: Data) -> URL? {
        let dir = directoryURL()
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            return nil
        }
        let ext = imageData.detectedImageExtension ?? "png"
        let url = dir.appendingPathComponent(UUID().uuidString + "." + ext)
        do {
            try imageData.write(to: url)
        } catch {
            return nil
        }
        return url
    }

    static func cleanupAll() {
        let dir = directoryURL()
        try? FileManager.default.removeItem(at: dir)
    }
}

private extension Data {
    var detectedImageExtension: String? {
        guard count >= 8 else { return nil }
        let bytes = [UInt8](prefix(8))
        if bytes.starts(with: [0x89, 0x50, 0x4E, 0x47]) { return "png" }
        if bytes.starts(with: [0xFF, 0xD8, 0xFF]) { return "jpg" }
        if bytes.starts(with: [0x47, 0x49, 0x46, 0x38]) { return "gif" }
        if bytes.starts(with: [0x49, 0x49]) || bytes.starts(with: [0x4D, 0x4D]) { return "tiff" }
        if count >= 12, Array(self[8 ..< 12]) == [0x57, 0x45, 0x42, 0x50] { return "webp" }
        return nil
    }
}

private extension MuxyTheme {
    @MainActor
    static func snapshotForeground() -> NSColor {
        NSColor(MuxyTheme.fg)
    }
}
