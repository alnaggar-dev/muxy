import Foundation

enum RichInputSubmitStrategy {
    case inline
    case bracketedPaste
    case delayedEnter
    case bracketedPasteDelayedEnter

    static let bracketedPasteStart = Data([0x1B, 0x5B, 0x32, 0x30, 0x30, 0x7E])
    static let bracketedPasteEnd = Data([0x1B, 0x5B, 0x32, 0x30, 0x31, 0x7E])

    static func strategy(for agentName: String?) -> RichInputSubmitStrategy {
        switch agentName {
        case "codex",
             "deepseek",
             "deepseek-tui": .bracketedPaste
        case "copilot": .bracketedPasteDelayedEnter
        case "claude",
             "opencode",
             "gemini",
             "auggie": .delayedEnter
        default: .inline
        }
    }
}
