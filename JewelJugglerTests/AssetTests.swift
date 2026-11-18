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

    @Test func everyTourAndWorkshopSymbolExists() {
        let symbols = TourCard.allCases.map(\.symbol) + Enchantment.allCases.map(\.symbol)
            + [TourStopKind.show, .tournament, .tavern, .banquet].map(\.symbol)
            + ["rhombus.fill", "hammer.fill", "map.fill", "suit.spade.fill", "bell.fill", "theatermasks.fill", "checkmark.circle.fill"]
        for name in symbols {
            #expect(UIImage(systemName: name) != nil, "Missing SF Symbol \(name)")
        }
    }

    @Test func guidePagesUseTheirOwnArt() {
        #expect(GuideView.pages.count == 11)
        #expect(Set(GuideView.pages.map(\.picture)).count == GuideView.pages.count)
        for page in GuideView.pages {
            if let art = page.art { #expect(UIImage(named: art) != nil) } else { #expect(UIImage(systemName: page.symbol ?? "") != nil) }
        }
    }
}
