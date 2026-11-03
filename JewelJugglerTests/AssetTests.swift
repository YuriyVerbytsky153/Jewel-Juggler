import Testing
import UIKit
@testable import JewelJuggler

@MainActor
@Suite("Generated assets")
struct AssetTests {
    @Test func everyArtNameResolves() {
        let names = Art.allNames
        #expect(names.count > 90)
        for name in names {
            #expect(UIImage(named: name) != nil, "Missing generated image \(name)")
        }
    }

    @Test func everySoundIsBundled() {
        for effect in SoundEffect.allCases {
            #expect(Bundle.main.url(forResource: effect.rawValue, withExtension: "wav") != nil, "Missing \(effect.rawValue).wav")
        }
        for track in ["music_menu", "music_run"] {
            #expect(Bundle.main.url(forResource: track, withExtension: "wav") != nil)
        }
    }

    @Test func guidePagesUseTheirOwnArt() {
        #expect(GuideView.pages.count == 9)
        #expect(Set(GuideView.pages.map(\.art)).count == 9)
    }
}
