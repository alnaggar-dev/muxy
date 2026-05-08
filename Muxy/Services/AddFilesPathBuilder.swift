import Foundation

enum AddFilesPathBuilder {
    static func text(for urls: [URL]) -> String {
        guard !urls.isEmpty else { return "" }
        return urls.map { ShellEscaper.escape($0.path) }.joined(separator: " ") + " "
    }
}
