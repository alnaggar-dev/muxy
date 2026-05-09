import Foundation

enum RichInputPreferences {
    static let fontSizeKey = "muxy.richInput.fontSize"
    static let defaultFontSize: Double = 13
    static let minFontSize: Double = 9
    static let maxFontSize: Double = 32
    static let fontStep: Double = 1

    static let layoutKey = "muxy.richInput.layout"
    static let exclusiveFocusKey = "muxy.richInput.exclusiveFocus"
    static let autoDetectKey = "muxy.richInput.autoDetectEnabled"
    static let clearAfterSendKey = "muxy.richInput.clearAfterSend"
}

enum RichInputLayout: String, Codable, CaseIterable, Identifiable {
    case vertical
    case horizontal

    static let defaultValue: RichInputLayout = .vertical

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .vertical: "Vertical (Side Panel)"
        case .horizontal: "Horizontal (Bottom Bar)"
        }
    }
}
