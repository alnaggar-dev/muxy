import Foundation

enum CLIAgentMetadata {
    struct Info: Equatable {
        let displayName: String
        let providerIconAsset: String?
    }

    static func info(forDetectorName name: String) -> Info {
        switch name {
        case "claude":
            Info(displayName: "Claude Code", providerIconAsset: "claude")
        case "codex":
            Info(displayName: "Codex", providerIconAsset: "codex")
        case "copilot":
            Info(displayName: "Copilot", providerIconAsset: "copilot")
        case "amp":
            Info(displayName: "Amp", providerIconAsset: "amp")
        case "droid":
            Info(displayName: "Droid", providerIconAsset: "factory")
        case "gemini":
            Info(displayName: "Gemini", providerIconAsset: nil)
        case "opencode":
            Info(displayName: "OpenCode", providerIconAsset: nil)
        case "auggie":
            Info(displayName: "Auggie", providerIconAsset: nil)
        case "goose":
            Info(displayName: "Goose", providerIconAsset: nil)
        case "deepseek",
             "deepseek-tui":
            Info(displayName: "DeepSeek", providerIconAsset: nil)
        default:
            Info(displayName: name, providerIconAsset: nil)
        }
    }
}
