import Foundation
import Observation

/// The Royal Tour map: set out, pick the road, rest at taverns and take tarot cards.
@MainActor
@Observable
final class TourViewModel {
    private let profileStore: ProfileStore
    private let haptics: HapticsService
    private let sound: SoundService

    var toast: Toast?
    /// The stop whose details are shown under the map.
    var selected: TourStop?
    var isConfirmingRetire = false

    init(profileStore: ProfileStore, haptics: HapticsService, sound: SoundService) {
        self.profileStore = profileStore
        self.haptics = haptics
        self.sound = sound
    }

    var tour: TourState? { profileStore.tour }
    var shards: Int { profileStore.shards }
    var maxBells: Int { profileStore.tourMaxBells }
    var toursWon: Int { profileStore.profile.toursWon }
    var bestDepth: Int { profileStore.profile.bestTourDepth }
    var costume: Costume { profileStore.profile.selectedCostume }

    func isReachable(_ stop: TourStop) -> Bool { tour?.isReachable(stop) ?? false }
    func isCleared(_ stop: TourStop) -> Bool { tour?.isCleared(stop) ?? false }
    func isCurrent(_ stop: TourStop) -> Bool { tour?.current == stop }

    func start() {
        do {
            try profileStore.startTour(seed: AppDependencies.randomSeed())
            selected = nil
            haptics.notify(.success)
            sound.play(.flip)
        } catch {
            show(error)
        }
    }

    func select(_ stop: TourStop) {
        guard isReachable(stop) else {
            haptics.notify(.warning)
            if tour?.offer.isEmpty == false {
                toast = Toast(message: "Choose a tarot card first.", style: .info)
            } else if !isCleared(stop) {
                toast = Toast(message: ProfileError.tourStopClosed.localizedDescription, style: .info)
            }
            return
        }
        haptics.selection()
        sound.play(.tap)
        selected = stop
    }

    /// Goes to the selected stop. Returns the show to perform, or nil after resting at a tavern.
    func travel() -> RunMode? {
        guard let stop = selected else { return nil }
        do {
            let mode = try profileStore.travel(to: stop)
            selected = nil
            if mode == nil {
                haptics.notify(.success)
                sound.play(.grace)
                toast = Toast(message: "A warm meal at \(stop.name). Bells restored.", style: .success)
            }
            return mode
        } catch {
            show(error)
            return nil
        }
    }

    func choose(_ card: TourCard) {
        do {
            try profileStore.chooseCard(card)
            haptics.notify(.success)
            sound.play(.flip)
            toast = Toast(message: "\(card.title) joins your hand.", style: .success)
        } catch {
            show(error)
        }
    }

    func retire() {
        do {
            try profileStore.retireTour()
            selected = nil
        } catch {
            show(error)
        }
    }

    private func show(_ error: Error) {
        haptics.notify(.warning)
        toast = Toast(message: error.localizedDescription, style: .warning)
    }
}

/// The Jeweller's Workshop: cut enchantments with shards and set them in the jewel case.
@MainActor
@Observable
final class WorkshopViewModel {
    private let profileStore: ProfileStore
    private let haptics: HapticsService
    private let sound: SoundService
    var toast: Toast?

    init(profileStore: ProfileStore, haptics: HapticsService, sound: SoundService) {
        self.profileStore = profileStore
        self.haptics = haptics
        self.sound = sound
    }

    enum Action: Equatable {
        case cut(Int)
        case wear
        case remove
    }

    var shards: Int { profileStore.shards }
    var slots: Int { profileStore.profile.jewelSlots }
    var equipped: [Enchantment] { profileStore.profile.equippedEnchantments }
    var nextSlotPrice: Int? { profileStore.nextSlotPrice }

    func owns(_ enchantment: Enchantment) -> Bool { profileStore.profile.owns(enchantment) }
    func canAfford(_ shards: Int) -> Bool { profileStore.shards >= shards }

    func action(for enchantment: Enchantment) -> Action {
        if !owns(enchantment) { return .cut(enchantment.price) }
        return profileStore.isEquipped(enchantment) ? .remove : .wear
    }

    func perform(_ enchantment: Enchantment) {
        do {
            switch action(for: enchantment) {
            case .cut:
                try profileStore.buyEnchantment(enchantment)
                haptics.notify(.success)
                sound.play(.buy)
                toast = Toast(message: profileStore.isEquipped(enchantment) ? "\(enchantment.title) is cut and set in the case." : "\(enchantment.title) is cut. Free a setting to wear it.", style: .success)
            case .wear:
                try profileStore.toggleEquip(enchantment)
                haptics.selection()
                sound.play(.tap)
                toast = Toast(message: "\(enchantment.title) set in the jewel case.", style: .success)
            case .remove:
                try profileStore.toggleEquip(enchantment)
                haptics.selection()
                sound.play(.tap)
            }
        } catch {
            haptics.notify(.warning)
            toast = Toast(message: error.localizedDescription, style: .warning)
        }
    }

    func buySlot() {
        do {
            try profileStore.buySlot()
            haptics.notify(.success)
            sound.play(.buy)
            toast = Toast(message: "A new setting is fitted to the jewel case.", style: .success)
        } catch {
            haptics.notify(.warning)
            toast = Toast(message: error.localizedDescription, style: .warning)
        }
    }
}
