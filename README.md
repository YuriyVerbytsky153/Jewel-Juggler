# Jewel Juggler

A candlelit court juggling arcade for iPhone and iPad (iOS 18+). The jester slides along the stage,
catches falling gems and tosses them back up, banks them into the court chest for ducats and keeps
every bell on his cap ringing. Offline, no ads, no real money.

Jira: IOS-1214 · Bundle ID `com.jeweljuggler.game29` · SwiftUI + SpriteKit + SwiftData, MVVM.

## Layout
- `JewelJuggler/Models` – pure rules (`RunSession`), gems, costumes, props, acts, achievements, SwiftData models.
- `JewelJuggler/Services` – `ProfileStore`, settings, haptics, sound.
- `JewelJuggler/Game` – `JugglerScene` (SpriteKit renderer and touch input).
- `JewelJuggler/Views`, `ViewModels`, `Components`, `Utilities` – the SwiftUI interface.
- `Artwork/` – `build.sh` + `parts/*.swift` paint every PNG and the app icon; `generate_sounds.swift` synthesises all audio.
- `Site/` – the one-page landing site (local, not deployed yet).

## Debug launch arguments
`--uitesting` (in-memory save, 5,000 ducats), `--freshstart` (with `--uitesting`: empty purse, guide on first show),
`--autopilot` (the jester plays himself), `--invincible` (never loses the last bell).

## Regenerating assets
```
cd Artwork && ./build.sh            # images + AppIcon into JewelJuggler/Assets.xcassets
swiftc -O -o /tmp/snd generate_sounds.swift && /tmp/snd ../JewelJuggler/Resources/Sounds
```
