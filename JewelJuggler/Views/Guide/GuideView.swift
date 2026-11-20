import SwiftUI

/// How to Play: illustrated pages, one per rule and mechanic.
struct GuideView: View {
    let isFirstRun: Bool
    let onBack: () -> Void
    @State private var page = 0

    struct Page: Identifiable {
        let id: Int
        /// A generated illustration, or nil to draw `symbol` on a velvet plate instead.
        let art: String?
        var symbol: String?
        let title: String
        let text: String

        /// What the page shows, for checking that no two pages share a picture.
        var picture: String { art ?? symbol ?? "" }
    }

    static let pages: [Page] = [
        Page(id: 0, art: Art.Guide.move, title: "Slide to move",
             text: "Drag anywhere on the stage to slide the jester left and right. Gems fall from above; catch them with his raised hands."),
        Page(id: 1, art: Art.Guide.toss, title: "Catch and toss",
             text: "Every caught gem is tossed back into the air. Keep them all aloft. A gem that hits the floor costs a bell, and when the cap has no bells left the curtain falls."),
        Page(id: 2, art: Art.Guide.bank, title: "Bank into the chest",
             text: "Tap the stage or the BANK button and the next gem you catch flies into the court chest. Only banked gems pay ducats, and the more a gem was tossed, the more it pays."),
        Page(id: 3, art: Art.Guide.wear, title: "Wear and cracks",
             text: "Each toss cracks a gem a little more. When its cracks glow red it cannot take another toss: bank it on the next catch or it shatters in your hands and takes a bell."),
        Page(id: 4, art: Art.Guide.chord, title: "Chord Fusion",
             text: "Catch three gems of the same colour in a row and the third fuses into a Crown Gem. Crowns fall faster, start fresh with no cracks and bank for five times the points."),
        Page(id: 5, art: Art.Guide.applause, title: "Applause and Encore",
             text: "The more gems are in the air at once, the faster the audience applauds. A full crowd calls an Encore: double points for a while, and the king throws in one more gem."),
        Page(id: 6, art: Art.Guide.decree, title: "Royal decrees",
             text: "The king announces decrees on a scroll a few seconds ahead. Ruby Hour: only rubies score, at triple value. Rotten Tomatoes: let them fall, catching one costs a bell. Candle Gust: the hall goes dark but every point is boosted."),
        Page(id: 7, art: Art.Guide.joker, title: "The Joker gem",
             text: "The rare harlequin gem counts as any colour and completes a chord. Treat it with care: dropping it costs two bells."),
        Page(id: 8, art: Art.Guide.jingle, title: "Jingle",
             text: "Catching a gem dead centre in the hands rings the cap. Ring it enough times and JINGLE is ready: press it to slow every gem for three seconds."),
        Page(id: 9, art: nil, symbol: "map.fill", title: "The Royal Tour",
             text: "Travel a road of shows to the King's Banquet. Your bells carry from stop to stop, taverns restore them, and every cleared show deals a tarot card that changes the rules for the rest of the tour."),
        Page(id: 10, art: nil, symbol: "hammer.fill", title: "Jeweller's Workshop",
             text: "Shattered gems and banked crowns leave shards. Cut them into enchantments and set them in your jewel case: now and then a gem in any show carries that power, marked with its sign."),
    ]

    var body: some View {
        VStack(spacing: 0) {
            if isFirstRun {
                Text("How to Play")
                    .font(.engraved(22, relativeTo: .title2))
                    .foregroundStyle(Theme.Colors.ink)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 8)
                    .background { Image(Art.Panel.ribbon).resizable(capInsets: PanelInsets.ribbon, resizingMode: .stretch) }
                    .padding(.top, 10)
            } else {
                CourtHeader(title: "How to Play", onBack: onBack)
            }
            TabView(selection: $page) {
                ForEach(Self.pages) { item in
                    ScrollView {
                        VStack(spacing: 16) {
                            illustration(item)
                                .clipShape(RoundedRectangle(cornerRadius: 18))
                                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Theme.Colors.gold, lineWidth: 3))
                                .accessibilityHidden(true)
                            VStack(spacing: 8) {
                                Text(item.title)
                                    .font(.engraved(22, relativeTo: .title2))
                                    .foregroundStyle(Theme.Colors.ink)
                                Text(item.text)
                                    .font(.court(.body, weight: .medium))
                                    .foregroundStyle(Theme.Colors.ink)
                                    .multilineTextAlignment(.center)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity)
                            .parchmentPanel(padding: 20)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .frame(maxWidth: 520)
                        .frame(maxWidth: .infinity)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    .tag(item.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            HStack(spacing: 12) {
                if page > 0 {
                    Button("Back") { withAnimation { page -= 1 } }
                        .buttonStyle(CourtButtonStyle(kind: .teal, size: 17))
                }
                if page < Self.pages.count - 1 {
                    if isFirstRun && page == 0 {
                        Button("Skip", action: onBack)
                            .buttonStyle(CourtButtonStyle(kind: .plum, size: 17))
                            .accessibilityIdentifier(AccessibilityID.Guide.done)
                    }
                    Button("Next") { withAnimation { page += 1 } }
                        .buttonStyle(CourtButtonStyle(kind: .gold, size: 19))
                        .accessibilityIdentifier(AccessibilityID.Guide.next)
                } else {
                    Button(isFirstRun ? "To the stage!" : "Got it", action: onBack)
                        .buttonStyle(CourtButtonStyle(kind: .gold, size: 19))
                        .accessibilityIdentifier(AccessibilityID.Guide.done)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
            .frame(maxWidth: 520)
        }
        .tiled(Art.Tile.velvet)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Guide.screen)
    }

    @ViewBuilder
    private func illustration(_ item: Page) -> some View {
        if let art = item.art {
            Image(art)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 360, maxHeight: 280)
        } else {
            Image(systemName: item.symbol ?? "questionmark")
                .font(.system(size: 96, weight: .bold))
                .foregroundStyle(Theme.Colors.saffron)
                .shadow(color: Theme.Colors.candle.opacity(0.5), radius: 16)
                .frame(maxWidth: 360)
                .frame(height: 220)
                .background(LinearGradient(colors: [Theme.Colors.velvetLight, Theme.Colors.velvetDeep], startPoint: .top, endPoint: .bottom))
        }
    }
}
