import Foundation
import WidgetKit

/// Simple store for persisting custom countdown events using UserDefaults.
/// Encodes events as JSON data under the key "customEvents".
final class CustomEventStore: ObservableObject {
    static let shared = CustomEventStore()

    @Published private(set) var events: [CustomEvent] = []

    private let key = "customEvents"
    private let defaults = UserDefaults.standard

    private init() {
        load()
    }

    func add(_ event: CustomEvent) {
        events.append(event)
        save()
    }

    func remove(_ event: CustomEvent) {
        events.removeAll { $0.id == event.id }
        save()
    }

    func update(_ event: CustomEvent) {
        if let idx = events.firstIndex(where: { $0.id == event.id }) {
            events[idx] = event
            save()
        }
    }

    func replaceAll(_ newEvents: [CustomEvent]) {
        events = newEvents
        save()
    }

    private func load() {
        guard let data = defaults.data(forKey: key) else { return }
        if let decoded = try? JSONDecoder().decode([CustomEvent].self, from: data) {
            events = decoded
        }
        mirrorEventsToWidgetSharedStorage()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(events) {
            defaults.set(data, forKey: key)
        }
        mirrorEventsToWidgetSharedStorage()
        // Ensure the widget refreshes when countdowns are added, updated, or removed.
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Mirrors the list of custom events into the shared app group so the widget
    /// can present them as options when the user taps "Edit Widget".
    private func mirrorEventsToWidgetSharedStorage() {
        let configs = events.map {
            WidgetCountdownConfig(
                id: $0.id,
                title: $0.title,
                date: $0.date,
                repeatsMonthly: $0.repeatsMonthly,
                monthlyDay: $0.monthlyDay,
                repeatsWeekly: $0.repeatsWeekly,
                weeklyInterval: $0.weeklyInterval
            )
        }
        guard let data = try? JSONEncoder().encode(configs) else { return }

        let sharedDefaults = UserDefaults(suiteName: WidgetConstants.appGroupId)
        sharedDefaults?.set(data, forKey: WidgetConstants.availableCountdownsKey)
    }
}
