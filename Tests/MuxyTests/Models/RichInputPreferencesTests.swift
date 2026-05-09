import Foundation
import Testing

@testable import Muxy

@Suite("RichInputPreferences")
struct RichInputPreferencesTests {
    @Test("default layout is vertical")
    func defaultLayout() {
        #expect(RichInputLayout.defaultValue == .vertical)
    }

    @Test("layout cases round-trip via raw value")
    func layoutRoundTrip() {
        for layout in RichInputLayout.allCases {
            #expect(RichInputLayout(rawValue: layout.rawValue) == layout)
        }
    }

    @Test("preference keys are stable identifiers")
    func preferenceKeys() {
        #expect(RichInputPreferences.layoutKey == "muxy.richInput.layout")
        #expect(RichInputPreferences.exclusiveFocusKey == "muxy.richInput.exclusiveFocus")
        #expect(RichInputPreferences.autoDetectKey == "muxy.richInput.autoDetectEnabled")
        #expect(RichInputPreferences.clearAfterSendKey == "muxy.richInput.clearAfterSend")
    }

    @Test("layouts have distinct display names")
    func displayNames() {
        let names = Set(RichInputLayout.allCases.map(\.displayName))
        #expect(names.count == RichInputLayout.allCases.count)
        #expect(!names.contains(""))
    }
}
