import Darwin
import Foundation
import os

private let logger = Logger(subsystem: "app.muxy", category: "CLIAgentDetector")

@MainActor
final class CLIAgentDetector {
    static let shared = CLIAgentDetector()

    private static let agentExecutables: Set<String> = [
        "claude",
        "claude-code",
        "@anthropic-ai",
        "codex",
        "gemini",
        "opencode",
        "amp",
        "droid",
        "auggie",
        "copilot",
        "goose",
        "deepseek",
        "deepseek-tui",
    ]

    private static let agentAliases: [String: String] = [
        "claude-code": "claude",
        "@anthropic-ai": "claude",
    ]

    private static let interpreters: Set<String> = [
        "node",
        "bun",
        "deno",
        "python",
        "python3",
        "ruby",
        "sh",
        "bash",
        "zsh",
    ]

    private static let scriptExtensions: Set<String> = [
        "js",
        "mjs",
        "cjs",
        "ts",
        "py",
        "rb",
    ]

    private static let pollInterval: TimeInterval = 1.5

    private final class Subscription {
        let paneID: UUID
        let onAgentDetected: (_ name: String, _ previous: String?) -> Void
        let onAgentExited: () -> Void
        var timer: Timer?
        var lastAgentName: String?

        init(
            paneID: UUID,
            onAgentDetected: @escaping (_ name: String, _ previous: String?) -> Void,
            onAgentExited: @escaping () -> Void
        ) {
            self.paneID = paneID
            self.onAgentDetected = onAgentDetected
            self.onAgentExited = onAgentExited
        }
    }

    private var subscriptions: [UUID: Subscription] = [:]

    private init() {}

    func start(
        paneID: UUID,
        onAgentDetected: @escaping (_ name: String, _ previous: String?) -> Void,
        onAgentExited: @escaping () -> Void
    ) {
        stop(paneID: paneID)
        let subscription = Subscription(
            paneID: paneID,
            onAgentDetected: onAgentDetected,
            onAgentExited: onAgentExited
        )
        subscriptions[paneID] = subscription
        tick(subscription: subscription)
        let timer = Timer.scheduledTimer(
            withTimeInterval: Self.pollInterval,
            repeats: true
        ) { [weak self] _ in
            guard let self else { return }
            MainActor.assumeIsolated {
                guard let current = self.subscriptions[paneID] else { return }
                self.tick(subscription: current)
            }
        }
        subscription.timer = timer
    }

    func stop(paneID: UUID) {
        guard let subscription = subscriptions.removeValue(forKey: paneID) else { return }
        subscription.timer?.invalidate()
        subscription.timer = nil
    }

    private func tick(subscription: Subscription) {
        let view = TerminalViewRegistry.shared.existingView(for: subscription.paneID)
        var candidate: String?
        if let pid = view?.foregroundProcessPID {
            candidate = Self.resolveAgentNameWalkingChildren(pid: pid)
        }
        let previous = subscription.lastAgentName
        subscription.lastAgentName = candidate
        guard previous != candidate else { return }
        if let candidate {
            subscription.onAgentDetected(candidate, previous)
        } else if previous != nil {
            subscription.onAgentExited()
        }
    }

    private static func resolveAgentNameWalkingChildren(pid: pid_t) -> String? {
        if let direct = resolveAgentName(pid: pid) {
            return direct
        }
        for childPID in childPIDs(parent: pid) {
            if let match = resolveAgentName(pid: childPID) {
                return match
            }
        }
        return nil
    }

    private static func childPIDs(parent: pid_t) -> [pid_t] {
        let bufferSize = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)
        guard bufferSize > 0 else { return [] }
        let count = Int(bufferSize) / MemoryLayout<pid_t>.size
        var pids = [pid_t](repeating: 0, count: count)
        let result = pids.withUnsafeMutableBufferPointer { buffer -> Int32 in
            proc_listpids(
                UInt32(PROC_ALL_PIDS),
                0,
                buffer.baseAddress,
                Int32(bufferSize)
            )
        }
        guard result > 0 else { return [] }
        let actualCount = Int(result) / MemoryLayout<pid_t>.size
        let validPIDs = pids.prefix(actualCount).filter { $0 > 0 }
        return validPIDs.filter { parentPID(of: $0) == parent }
    }

    private static func parentPID(of pid: pid_t) -> pid_t {
        var info = proc_bsdinfo()
        let size = MemoryLayout<proc_bsdinfo>.size
        let result = withUnsafeMutablePointer(to: &info) { ptr in
            proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, ptr, Int32(size))
        }
        guard result > 0 else { return 0 }
        return pid_t(info.pbi_ppid)
    }

    private static func resolveAgentName(pid: pid_t) -> String? {
        let imagePath = imagePath(pid: pid)
        let imageName = imagePath.map { ($0 as NSString).lastPathComponent }

        if let imageName, agentExecutables.contains(imageName) {
            return canonicalAgentName(imageName)
        }
        if let imagePath, let match = matchInPath(imagePath) {
            return match
        }

        guard let imageName, interpreters.contains(imageName) else { return nil }
        guard let argv = readArgv(pid: pid) else { return nil }
        if let match = resolveCandidateFromInterpreterArgv(argv) {
            return match
        }
        for arg in argv {
            if let match = matchInPath(arg) {
                return match
            }
        }
        logger.debug("CLIAgentDetector: pid \(pid) imageName=\(imageName) argv=\(argv.joined(separator: " ")) — no agent match")
        return nil
    }

    private static func matchInPath(_ path: String) -> String? {
        let lower = path.lowercased()
        for component in lower.split(whereSeparator: { $0 == "/" || $0 == "\\" }) {
            let stripped = stripScriptExtension(String(component))
            if agentExecutables.contains(stripped) {
                return canonicalAgentName(stripped)
            }
        }
        return nil
    }

    private static func canonicalAgentName(_ name: String) -> String {
        agentAliases[name] ?? name
    }

    private static let pidPathBufferSize = 4 * Int(MAXPATHLEN)

    private static func imagePath(pid: pid_t) -> String? {
        var pathBuffer = [UInt8](repeating: 0, count: pidPathBufferSize)
        let result = proc_pidpath(pid, &pathBuffer, UInt32(pathBuffer.count))
        guard result > 0 else { return nil }
        guard let path = String(bytes: pathBuffer.prefix(Int(result)), encoding: .utf8) else { return nil }
        return path.isEmpty ? nil : path
    }

    private static func resolveCandidateFromInterpreterArgv(_ argv: [String]) -> String? {
        guard argv.count >= 2 else { return nil }
        for arg in argv.dropFirst() {
            guard !arg.hasPrefix("-") else { continue }
            let base = (arg as NSString).lastPathComponent
            let stripped = stripScriptExtension(base)
            if agentExecutables.contains(stripped) {
                return canonicalAgentName(stripped)
            }
            break
        }
        guard let firstScript = argv.dropFirst().first(where: { !$0.hasPrefix("-") }) else { return nil }
        let url = URL(fileURLWithPath: firstScript)
        var current = url.deletingLastPathComponent()
        for _ in 0 ..< 5 {
            let component = current.lastPathComponent
            if !component.isEmpty, agentExecutables.contains(component) {
                return canonicalAgentName(component)
            }
            let parent = current.deletingLastPathComponent()
            guard parent.path != current.path else { break }
            current = parent
        }
        return nil
    }

    private static func stripScriptExtension(_ name: String) -> String {
        let lower = name.lowercased()
        for ext in scriptExtensions {
            let suffix = "." + ext
            if lower.hasSuffix(suffix) {
                return String(name.dropLast(suffix.count))
            }
        }
        return name
    }

    private static func readArgv(pid: pid_t) -> [String]? {
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        var size: size_t = 0
        let probe = mib.withUnsafeMutableBufferPointer { buffer -> Int32 in
            sysctl(buffer.baseAddress, UInt32(buffer.count), nil, &size, nil, 0)
        }
        guard probe == 0, size > MemoryLayout<Int32>.size else { return nil }
        var buffer = [UInt8](repeating: 0, count: size)
        let result = buffer.withUnsafeMutableBufferPointer { bufferPtr -> Int32 in
            mib.withUnsafeMutableBufferPointer { mibPtr in
                sysctl(mibPtr.baseAddress, UInt32(mibPtr.count), bufferPtr.baseAddress, &size, nil, 0)
            }
        }
        guard result == 0, size > MemoryLayout<Int32>.size else { return nil }
        return parseProcArgs(buffer: buffer, size: size)
    }

    private static func parseProcArgs(buffer: [UInt8], size: size_t) -> [String]? {
        let argcSize = MemoryLayout<Int32>.size
        guard size > argcSize else { return nil }
        var argc: Int32 = 0
        for byteIndex in 0 ..< argcSize {
            argc |= Int32(buffer[byteIndex]) << (byteIndex * 8)
        }
        guard argc > 0 else { return nil }
        var index = argcSize
        while index < size, buffer[index] != 0 {
            index += 1
        }
        while index < size, buffer[index] == 0 {
            index += 1
        }
        var argv: [String] = []
        argv.reserveCapacity(Int(argc))
        while argv.count < Int(argc), index < size {
            let start = index
            while index < size, buffer[index] != 0 {
                index += 1
            }
            if index > start {
                let bytes = Array(buffer[start ..< index])
                if let string = String(bytes: bytes, encoding: .utf8) {
                    argv.append(string)
                }
            }
            while index < size, buffer[index] == 0 {
                index += 1
            }
        }
        return argv.isEmpty ? nil : argv
    }
}
