import Foundation
import Testing

@testable import Muxy

@Suite("CLIAgentMetadata")
struct CLIAgentMetadataTests {
    @Test("known agents map to bundled provider icons")
    func knownAgents() {
        #expect(CLIAgentMetadata.info(forDetectorName: "claude") ==
            CLIAgentMetadata.Info(displayName: "Claude Code", providerIconAsset: "claude"))
        #expect(CLIAgentMetadata.info(forDetectorName: "codex") ==
            CLIAgentMetadata.Info(displayName: "Codex", providerIconAsset: "codex"))
        #expect(CLIAgentMetadata.info(forDetectorName: "copilot") ==
            CLIAgentMetadata.Info(displayName: "Copilot", providerIconAsset: "copilot"))
        #expect(CLIAgentMetadata.info(forDetectorName: "amp") ==
            CLIAgentMetadata.Info(displayName: "Amp", providerIconAsset: "amp"))
        #expect(CLIAgentMetadata.info(forDetectorName: "droid") ==
            CLIAgentMetadata.Info(displayName: "Droid", providerIconAsset: "factory"))
    }

    @Test("agents without bundled icons return nil asset")
    func agentsWithoutIcon() {
        #expect(CLIAgentMetadata.info(forDetectorName: "gemini").providerIconAsset == nil)
        #expect(CLIAgentMetadata.info(forDetectorName: "opencode").providerIconAsset == nil)
        #expect(CLIAgentMetadata.info(forDetectorName: "auggie").providerIconAsset == nil)
        #expect(CLIAgentMetadata.info(forDetectorName: "goose").providerIconAsset == nil)
    }

    @Test("deepseek aliases share the same display name")
    func deepseekAliases() {
        let primary = CLIAgentMetadata.info(forDetectorName: "deepseek")
        let alias = CLIAgentMetadata.info(forDetectorName: "deepseek-tui")
        #expect(primary.displayName == "DeepSeek")
        #expect(alias.displayName == "DeepSeek")
    }

    @Test("unknown agent falls back to its raw name")
    func unknownAgent() {
        let info = CLIAgentMetadata.info(forDetectorName: "mystery-cli")
        #expect(info.displayName == "mystery-cli")
        #expect(info.providerIconAsset == nil)
    }
}
