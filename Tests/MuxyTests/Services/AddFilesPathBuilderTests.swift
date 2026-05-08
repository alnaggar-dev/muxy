import Foundation
import Testing

@testable import Muxy

@Suite("AddFilesPathBuilder")
struct AddFilesPathBuilderTests {
    @Test("empty input returns empty string")
    func emptyInput() {
        #expect(AddFilesPathBuilder.text(for: []) == "")
    }

    @Test("single plain path is followed by a trailing space")
    func singlePlainPath() {
        let url = URL(fileURLWithPath: "/Users/alice/file.txt")
        #expect(AddFilesPathBuilder.text(for: [url]) == "/Users/alice/file.txt ")
    }

    @Test("path with spaces is shell-escaped")
    func pathWithSpaces() {
        let url = URL(fileURLWithPath: "/tmp/my file.txt")
        #expect(AddFilesPathBuilder.text(for: [url]) == "'/tmp/my file.txt' ")
    }

    @Test("multiple paths are joined with single spaces and trailing space")
    func multiplePaths() {
        let urls = [
            URL(fileURLWithPath: "/tmp/a.txt"),
            URL(fileURLWithPath: "/tmp/b.txt"),
        ]
        #expect(AddFilesPathBuilder.text(for: urls) == "/tmp/a.txt /tmp/b.txt ")
    }

    @Test("preserves caller-provided ordering")
    func preservesOrder() {
        let urls = [
            URL(fileURLWithPath: "/tmp/z"),
            URL(fileURLWithPath: "/tmp/a"),
            URL(fileURLWithPath: "/tmp/m"),
        ]
        #expect(AddFilesPathBuilder.text(for: urls) == "/tmp/z /tmp/a /tmp/m ")
    }

    @Test("mixed escapable and plain paths")
    func mixed() {
        let urls = [
            URL(fileURLWithPath: "/tmp/plain"),
            URL(fileURLWithPath: "/tmp/with space"),
        ]
        #expect(AddFilesPathBuilder.text(for: urls) == "/tmp/plain '/tmp/with space' ")
    }
}
