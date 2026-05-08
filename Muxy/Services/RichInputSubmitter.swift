import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
enum RichInputSubmitter {
    private static let imagePasteDelay: Duration = .milliseconds(300)
    private static let initialDelay: Duration = .milliseconds(50)

    enum Segment: Equatable {
        case text(String)
        case image(URL)
    }

    static func submit(richInput: RichInputState, paneID: UUID, appendReturn: Bool) {
        let body = richInput.text
        let fileAttachments = richInput.fileAttachments
        let imageAttachments = richInput.imageAttachments
        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBody.isEmpty || !fileAttachments.isEmpty || !imageAttachments.isEmpty else { return }

        let pathParts = fileAttachments.map { ShellEscaper.escape($0.path) }
        var combined = ""
        if pathParts.isEmpty {
            combined = body
        } else if trimmedBody.isEmpty {
            combined = pathParts.joined(separator: " ")
        } else {
            combined = pathParts.joined(separator: " ") + " " + body
        }

        let segments = tokenize(text: combined, images: imageAttachments)
        let strategy = RichInputSubmitStrategy.default

        Task { @MainActor in
            let cleanupURLs = (imageAttachments + fileAttachments).filter {
                $0.path.hasPrefix(RichInputTempFiles.directoryURL().path)
            }

            guard let view = TerminalViewRegistry.shared.existingView(for: paneID) else { return }
            view.clearTerminalInput()
            try? await Task.sleep(for: initialDelay)

            for segment in segments {
                switch segment {
                case let .text(chunk):
                    if !chunk.isEmpty {
                        view.submitRichInput(text: chunk, strategy: strategy)
                    }
                case let .image(url):
                    view.pasteImageURL(url)
                    try? await Task.sleep(for: imagePasteDelay)
                }
            }

            if appendReturn {
                view.sendRemoteBytes(Data([0x0D]))
            }

            richInput.reset()
            view.window?.makeFirstResponder(view)

            for url in cleanupURLs {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }

    nonisolated static func tokenize(text: String, images: [URL]) -> [Segment] {
        guard !images.isEmpty else {
            return text.isEmpty ? [] : [.text(text)]
        }
        var segments: [Segment] = []
        let ns = text as NSString
        var cursor = 0
        let length = ns.length
        let pattern = "\\[Image (\\d+)\\]"
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return text.isEmpty ? [] : [.text(text)]
        }
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: length))
        for match in matches {
            guard match.numberOfRanges == 2 else { continue }
            let indexRange = match.range(at: 1)
            let indexString = ns.substring(with: indexRange)
            guard let imageIndex = Int(indexString),
                  imageIndex >= 1,
                  imageIndex <= images.count
            else { continue }
            if match.range.location > cursor {
                let chunk = ns.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
                if !chunk.isEmpty { segments.append(.text(chunk)) }
            }
            segments.append(.image(images[imageIndex - 1]))
            cursor = match.range.location + match.range.length
        }
        if cursor < length {
            let tail = ns.substring(with: NSRange(location: cursor, length: length - cursor))
            if !tail.isEmpty { segments.append(.text(tail)) }
        }
        return segments
    }
}
