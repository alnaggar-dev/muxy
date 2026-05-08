import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
enum RichInputSubmitter {
    private static let imagePasteDelay: Duration = .milliseconds(300)
    private static let modePrefixDelay: Duration = .milliseconds(50)

    static func submit(state: TerminalPaneState) {
        let richInput = state.richInput
        let body = richInput.text
        let attachments = richInput.attachments
        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBody.isEmpty || !attachments.isEmpty else { return }

        let agentName = richInput.detectedAgentName
        let agentActive = agentName != nil
        let (imageAttachments, pathAttachments) = classifyAttachments(attachments, agentActive: agentActive)

        let pathParts = pathAttachments.map { ShellEscaper.escape($0.path) }
        var combined = ""
        if pathParts.isEmpty {
            combined = body
        } else if trimmedBody.isEmpty {
            combined = pathParts.joined(separator: " ")
        } else {
            combined = pathParts.joined(separator: " ") + " " + body
        }
        combined = combined.trimmingCharacters(in: .whitespacesAndNewlines)

        let strategy = RichInputSubmitStrategy.strategy(for: agentName)
        let paneID = state.id

        Task { @MainActor in
            let cleanupURLs = (imageAttachments + pathAttachments).filter {
                $0.path.hasPrefix(RichInputTempFiles.directoryURL().path)
            }

            var textForSubmit = combined
            if agentActive, let firstByte = combined.utf8.first,
               combined.utf8.count > 1, firstByte == 0x21 || firstByte == 0x26
            {
                let view = TerminalViewRegistry.shared.existingView(for: paneID)
                view?.sendRemoteBytes(Data([firstByte]))
                try? await Task.sleep(for: modePrefixDelay)
                textForSubmit = String(combined.dropFirst())
            }

            for url in imageAttachments {
                let view = TerminalViewRegistry.shared.existingView(for: paneID)
                guard let view else { break }
                view.pasteImageURL(url)
                try? await Task.sleep(for: imagePasteDelay)
            }

            let submitView = TerminalViewRegistry.shared.existingView(for: paneID)
            submitView?.submitRichInput(text: textForSubmit, strategy: strategy)

            richInput.text = ""
            richInput.attachments = []

            for url in cleanupURLs {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }

    private static func classifyAttachments(
        _ attachments: [URL],
        agentActive: Bool
    ) -> (images: [URL], paths: [URL]) {
        guard agentActive else { return ([], attachments) }
        var images: [URL] = []
        var paths: [URL] = []
        for url in attachments {
            if isImage(url) {
                images.append(url)
            } else {
                paths.append(url)
            }
        }
        return (images, paths)
    }

    private static func isImage(_ url: URL) -> Bool {
        guard let utType = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType else {
            return false
        }
        return utType.conforms(to: .image)
    }
}
