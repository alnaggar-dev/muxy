import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct RichInputBar: View {
    @Bindable var state: RichInputState
    let worktreeKey: WorktreeKey
    let onDismiss: () -> Void
    let onSubmit: (_ appendReturn: Bool) -> Void

    @AppStorage(RichInputPreferences.fontSizeKey) private var fontSize: Double = RichInputPreferences.defaultFontSize
    @State private var keyMonitor: Any?
    @State private var editorContentHeight: CGFloat = 0

    private static let editorVerticalInset: CGFloat = 6
    private static let editorMaxLines: Int = 10

    private var editorLineHeight: CGFloat {
        let font = NSFont.systemFont(ofSize: clampedFontSize)
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

    private var clampedFontSize: CGFloat {
        let bounded = min(max(fontSize, RichInputPreferences.minFontSize), RichInputPreferences.maxFontSize)
        return CGFloat(bounded)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle().fill(MuxyTheme.border).frame(height: 1)

            VStack(alignment: .leading, spacing: 6) {
                if !state.fileAttachments.isEmpty {
                    RichInputAttachmentChipsView(
                        attachments: state.fileAttachments,
                        onRemove: { url in
                            state.fileAttachments.removeAll { $0 == url }
                        }
                    )
                }

                MarkdownTextEditor(
                    text: $state.text,
                    focusVersion: state.focusVersion,
                    configuration: editorConfiguration,
                    callbacks: editorCallbacks
                )
                .frame(height: clampedEditorHeight)

                toolbar
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .background(MuxyTheme.bg)
        .onDrop(of: [UTType.fileURL, UTType.image], isTargeted: nil) { providers in
            handleDrop(providers: providers)
        }
        .onAppear { installSubmitMonitor() }
        .onDisappear {
            removeSubmitMonitor()
            RichInputDraftStore.shared.flush()
        }
        .onChange(of: state.text) { persistDraft() }
        .onChange(of: state.fileAttachments) { persistDraft() }
        .onChange(of: state.imageAttachments) { persistDraft() }
    }

    private var toolbar: some View {
        HStack(spacing: 6) {
            Button(action: pickAttachment) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(RichInputToolbarButtonStyle())
            .accessibilityLabel("Add attachment")
            .help("Add attachment")

            if let agentName = state.detectedAgentName {
                agentChip(agentName: agentName)
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

            Button {
                onSubmit(true)
            } label: {
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
            .accessibilityLabel("Send")
        }
    }

    private func agentChip(agentName: String) -> some View {
        let info = CLIAgentMetadata.info(forDetectorName: agentName)
        return HStack(spacing: 4) {
            if let asset = info.providerIconAsset {
                ProviderIconView(
                    iconName: asset,
                    size: 10,
                    style: .monochrome(MuxyTheme.accent)
                )
            } else {
                Image(systemName: "sparkles")
                    .font(.system(size: 9, weight: .semibold))
            }
            Text(info.displayName)
                .font(.system(size: 10, weight: .medium))
                .lineLimit(1)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .foregroundStyle(MuxyTheme.accent)
        .background(MuxyTheme.accentSoft)
        .clipShape(Capsule())
        .help("Active agent: \(info.displayName)")
        .accessibilityLabel("Active agent: \(info.displayName)")
    }

    private var editorConfiguration: MarkdownTextEditor.Configuration {
        MarkdownTextEditor.Configuration(
            font: .systemFont(ofSize: clampedFontSize),
            insets: NSSize(width: 6, height: Self.editorVerticalInset),
            lineWrapping: true,
            grabsFirstResponderOnAppear: true
        )
    }

    private var editorCallbacks: MarkdownTextEditor.Callbacks {
        MarkdownTextEditor.Callbacks(
            onSubmit: { onSubmit(true) },
            onPasteImageData: { data in
                guard let url = RichInputImageStorage.write(imageData: data) else { return }
                insertImagePlaceholder(for: url)
            },
            onPasteFileURL: { url in
                guard !state.fileAttachments.contains(url) else { return }
                state.fileAttachments.append(url)
            },
            onContentHeightChange: { height in
                editorContentHeight = height
            }
        )
    }

    private func insertImagePlaceholder(for url: URL) {
        let placeholder = state.nextImagePlaceholder(for: url)
        state.text.append(placeholder)
    }

    private func persistDraft() {
        RichInputDraftStore.shared.scheduleSave(state.draft, for: worktreeKey)
    }

    private func increaseFontSize() {
        fontSize = min(RichInputPreferences.maxFontSize, fontSize + RichInputPreferences.fontStep)
    }

    private func decreaseFontSize() {
        fontSize = max(RichInputPreferences.minFontSize, fontSize - RichInputPreferences.fontStep)
    }

    private func pickAttachment() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = true
        panel.message = "Select files or folders to attach"
        guard panel.runModal() == .OK else { return }
        for url in panel.urls where !state.fileAttachments.contains(url) {
            state.fileAttachments.append(url)
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
                        if !state.fileAttachments.contains(url) {
                            state.fileAttachments.append(url)
                        }
                    }
                }
                consumed = true
                continue
            }
            if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                    guard let data, let url = RichInputImageStorage.write(imageData: data) else { return }
                    Task { @MainActor in
                        insertImagePlaceholder(for: url)
                    }
                }
                consumed = true
            }
        }
        return consumed
    }

    private func installSubmitMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            guard NSApp.keyWindow?.firstResponder is MarkdownEditingTextView else { return event }
            let store = KeyBindingStore.shared
            if store.combo(for: .submitRichInput).matches(event: event) {
                Task { @MainActor in onSubmit(true) }
                return nil
            }
            if store.combo(for: .submitRichInputWithoutReturn).matches(event: event) {
                Task { @MainActor in onSubmit(false) }
                return nil
            }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard flags.subtracting(.shift) == .command else { return event }
            switch event.charactersIgnoringModifiers?.lowercased() {
            case "=",
                 "+":
                Task { @MainActor in increaseFontSize() }
                return nil
            case "-":
                Task { @MainActor in decreaseFontSize() }
                return nil
            default:
                return event
            }
        }
    }

    private func removeSubmitMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }
}
