import Foundation

enum RichInputSubmitStrategy {
    case inline
    case bracketedPaste

    static let bracketedPasteStart = Data([0x1B, 0x5B, 0x32, 0x30, 0x30, 0x7E])
    static let bracketedPasteEnd = Data([0x1B, 0x5B, 0x32, 0x30, 0x31, 0x7E])

    static var `default`: RichInputSubmitStrategy { .bracketedPaste }
}
