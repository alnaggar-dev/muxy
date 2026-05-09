import Foundation
import Testing

@testable import Muxy

@MainActor
@Suite("RichInputState")
struct RichInputStateTests {
    @Test("agent runtime fields are excluded from draft round-trip")
    func draftIgnoresAgentFields() {
        let state = RichInputState()
        let paneID = UUID()
        state.text = "hello"
        state.setDetectedAgentName("claude", for: paneID)
        state.markAgentPaneDismissed(paneID)

        let draft = state.draft
        let restored = RichInputState()
        restored.apply(draft)

        #expect(restored.text == "hello")
        #expect(restored.detectedAgentName(for: paneID) == nil)
        #expect(!restored.isAgentPaneDismissed(paneID))
    }

    @Test("nextImagePlaceholder appends to attachments and increments counter")
    func nextImagePlaceholder() {
        let state = RichInputState()
        let url1 = URL(fileURLWithPath: "/tmp/a.png")
        let url2 = URL(fileURLWithPath: "/tmp/b.png")

        let placeholder1 = state.nextImagePlaceholder(for: url1)
        let placeholder2 = state.nextImagePlaceholder(for: url2)

        #expect(placeholder1 == "[Image 1]")
        #expect(placeholder2 == "[Image 2]")
        #expect(state.imageAttachments == [url1, url2])
        #expect(state.imagePlaceholderCounter == 2)
    }

    @Test("clearComposition resets text, attachments, and counter")
    func clearComposition() {
        let state = RichInputState()
        state.text = "draft"
        state.fileAttachments = [URL(fileURLWithPath: "/tmp/x.swift")]
        _ = state.nextImagePlaceholder(for: URL(fileURLWithPath: "/tmp/y.png"))

        state.clearComposition()

        #expect(state.text.isEmpty)
        #expect(state.fileAttachments.isEmpty)
        #expect(state.imageAttachments.isEmpty)
        #expect(state.imagePlaceholderCounter == 0)
    }

    @Test("conditional clear preserves newer composition")
    func conditionalClearComposition() {
        let state = RichInputState()
        state.text = "submitted"
        let submittedDraft = state.draft

        state.text = "next"
        let cleared = state.clearComposition(ifCurrentDraftEquals: submittedDraft)

        #expect(!cleared)
        #expect(state.text == "next")
    }

    @Test("agent detection and dismissal are pane scoped")
    func agentStateIsPaneScoped() {
        let state = RichInputState()
        let paneA = UUID()
        let paneB = UUID()

        state.setDetectedAgentName("claude", for: paneA)
        state.markAgentPaneDismissed(paneA)

        #expect(state.detectedAgentName(for: paneA) == "claude")
        #expect(state.detectedAgentName(for: paneB) == nil)
        #expect(state.isAgentPaneDismissed(paneA))
        #expect(!state.isAgentPaneDismissed(paneB))

        state.setDetectedAgentName(nil, for: paneA)
        state.clearAgentPaneDismissal(paneA)

        #expect(state.detectedAgentName(for: paneA) == nil)
        #expect(!state.isAgentPaneDismissed(paneA))
    }
}
