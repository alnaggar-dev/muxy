import AppKit
import SwiftUI

struct TerminalPaneFooter: View {
    @Bindable var state: TerminalPaneState
    @Bindable var branchObserver: PaneBranchObserver
    let paneID: UUID
    let isInteractive: Bool

    private var displayDirectory: String {
        let raw = state.currentWorkingDirectory ?? state.projectPath
        return abbreviatePath(raw)
    }

    private var richInputShortcutLabel: String {
        KeyBindingStore.shared.combo(for: .toggleRichInput).displayString
    }

    var body: some View {
        HStack(spacing: 6) {
            addFilesButton
            richInputToggleButton
            Spacer(minLength: 8)
            cwdChip
            if let branch = branchObserver.branch {
                branchChip(branch: branch)
            }
            agentFavicon
        }
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(MuxyTheme.bg)
        .overlay(
            Rectangle()
                .fill(MuxyTheme.border)
                .frame(height: 1),
            alignment: .top
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Terminal status bar")
    }

    private var addFilesButton: some View {
        Button(action: pickAndInsertPaths) {
            Image(systemName: "plus")
                .font(.system(size: 11, weight: .semibold))
        }
        .buttonStyle(RichInputToolbarButtonStyle())
        .disabled(!isInteractive)
        .accessibilityLabel("Insert file paths")
        .help("Insert file paths into the terminal")
    }

    private var richInputToggleButton: some View {
        Button(action: toggleRichInput) {
            HStack(spacing: 6) {
                Image(systemName: "keyboard")
                    .font(.system(size: 10, weight: .semibold))
                Text("Rich Input")
                    .font(.system(size: 11, weight: .medium))
                Text(richInputShortcutLabel)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(MuxyTheme.fgDim)
            }
        }
        .buttonStyle(ChipButtonStyle())
        .disabled(!isInteractive)
        .accessibilityLabel(state.richInput.isVisible ? "Hide Rich Input" : "Show Rich Input")
        .help(state.richInput.isVisible ? "Hide Rich Input" : "Show Rich Input")
    }

    private var cwdChip: some View {
        FooterChip(
            systemImage: "folder",
            text: displayDirectory,
            tooltip: state.currentWorkingDirectory ?? state.projectPath
        )
    }

    private func branchChip(branch: String) -> some View {
        FooterChip(
            systemImage: "arrow.triangle.branch",
            text: branch,
            tooltip: "Branch: \(branch)"
        )
    }

    @ViewBuilder
    private var agentFavicon: some View {
        if let agentName = state.richInput.detectedAgentName {
            let info = CLIAgentMetadata.info(forDetectorName: agentName)
            Group {
                if let asset = info.providerIconAsset {
                    ProviderIconView(
                        iconName: asset,
                        size: 14,
                        style: .monochrome(MuxyTheme.fg)
                    )
                } else {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12))
                        .foregroundStyle(MuxyTheme.fg)
                }
            }
            .frame(width: 18, height: 18)
            .help(info.displayName)
            .accessibilityLabel("Active agent: \(info.displayName)")
        }
    }

    private func toggleRichInput() {
        guard isInteractive else { return }
        let willOpen = !state.richInput.isVisible
        state.richInput.isVisible = willOpen
        if willOpen {
            state.richInput.focusVersion += 1
            state.richInput.userDismissedDuringAgentRun = false
            return
        }
        if state.richInput.detectedAgentName != nil {
            state.richInput.userDismissedDuringAgentRun = true
        }
        let view = TerminalViewRegistry.shared.existingView(for: paneID)
        DispatchQueue.main.async {
            view?.window?.makeFirstResponder(view)
        }
    }

    private func pickAndInsertPaths() {
        guard isInteractive else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.message = "Select files or folders to insert"
        guard panel.runModal() == .OK else { return }
        let text = AddFilesPathBuilder.text(for: panel.urls)
        guard !text.isEmpty else { return }
        let view = TerminalViewRegistry.shared.existingView(for: paneID)
        view?.sendRemoteBytes(Data(text.utf8))
        DispatchQueue.main.async {
            view?.window?.makeFirstResponder(view)
        }
    }

    private func abbreviatePath(_ path: String) -> String {
        let home = NSHomeDirectory()
        guard !home.isEmpty, path.hasPrefix(home) else { return path }
        let suffix = path.dropFirst(home.count)
        return "~" + suffix
    }
}

private struct FooterChip: View {
    let systemImage: String
    let text: String
    let tooltip: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.system(size: 10, weight: .semibold))
            Text(text)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .foregroundStyle(MuxyTheme.fgMuted)
        .background(MuxyTheme.surface)
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(MuxyTheme.border, lineWidth: 1))
        .help(tooltip)
    }
}

private struct ChipButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .foregroundStyle(MuxyTheme.fgMuted)
            .background(configuration.isPressed ? MuxyTheme.hover : MuxyTheme.surface)
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(MuxyTheme.border, lineWidth: 1))
            .contentShape(Capsule())
    }
}
