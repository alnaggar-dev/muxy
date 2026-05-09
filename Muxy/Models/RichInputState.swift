import Foundation

@MainActor
@Observable
final class RichInputState {
    var text: String = ""
    var fileAttachments: [URL] = []
    var imageAttachments: [URL] = []
    var imagePlaceholderCounter: Int = 0
    var focusVersion: Int = 0
    var detectedAgentNamesByPaneID: [UUID: String] = [:]
    var dismissedAgentPaneIDs: Set<UUID> = []

    func nextImagePlaceholder(for url: URL) -> String {
        imagePlaceholderCounter += 1
        imageAttachments.append(url)
        return "[Image \(imagePlaceholderCounter)]"
    }

    func apply(_ draft: RichInputDraft) {
        text = draft.text
        fileAttachments = draft.fileAttachments
        imageAttachments = draft.imageAttachments
        imagePlaceholderCounter = draft.imagePlaceholderCounter
    }

    var draft: RichInputDraft {
        RichInputDraft(
            text: text,
            fileAttachments: fileAttachments,
            imageAttachments: imageAttachments,
            imagePlaceholderCounter: imagePlaceholderCounter
        )
    }

    func clearComposition() {
        text = ""
        fileAttachments = []
        imageAttachments = []
        imagePlaceholderCounter = 0
    }

    @discardableResult
    func clearComposition(ifCurrentDraftEquals submittedDraft: RichInputDraft) -> Bool {
        guard draft == submittedDraft else { return false }
        clearComposition()
        return true
    }

    func detectedAgentName(for paneID: UUID?) -> String? {
        guard let paneID else { return nil }
        return detectedAgentNamesByPaneID[paneID]
    }

    func setDetectedAgentName(_ name: String?, for paneID: UUID) {
        if let name {
            detectedAgentNamesByPaneID[paneID] = name
        } else {
            detectedAgentNamesByPaneID.removeValue(forKey: paneID)
        }
    }

    func isAgentPaneDismissed(_ paneID: UUID) -> Bool {
        dismissedAgentPaneIDs.contains(paneID)
    }

    func markAgentPaneDismissed(_ paneID: UUID) {
        dismissedAgentPaneIDs.insert(paneID)
    }

    func clearAgentPaneDismissal(_ paneID: UUID) {
        dismissedAgentPaneIDs.remove(paneID)
    }
}
