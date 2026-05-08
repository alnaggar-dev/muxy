import Foundation

@MainActor
@Observable
final class RichInputState {
    var text: String = ""
    var fileAttachments: [URL] = []
    var imageAttachments: [URL] = []
    var imagePlaceholderCounter: Int = 0
    var focusVersion: Int = 0

    func nextImagePlaceholder(for url: URL) -> String {
        imagePlaceholderCounter += 1
        imageAttachments.append(url)
        return "[Image \(imagePlaceholderCounter)]"
    }

    func reset() {
        text = ""
        fileAttachments = []
        imageAttachments = []
        imagePlaceholderCounter = 0
    }
}
