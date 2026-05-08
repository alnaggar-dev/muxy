import Foundation

@MainActor
@Observable
final class RichInputState {
    var isVisible: Bool = false
    var text: String = ""
    var attachments: [URL] = []
    var focusVersion: Int = 0
    var userDismissedDuringAgentRun: Bool = false
    var detectedAgentName: String?
}
