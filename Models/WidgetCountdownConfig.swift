import Foundation
import WidgetKit

/// Shared configuration for the home screen widget's selected countdown.
/// Stored in an app group so both the main app and the widget extension can access it.
struct WidgetCountdownConfig: Codable {
    let id: UUID
    let title: String
    let date: Date
    let subtitle: String?

    // Recurrence configuration (mirrors CustomEvent)
    var repeatsMonthly: Bool = false
    var monthlyDay: Int? = nil
    var repeatsWeekly: Bool = false
    var weeklyInterval: Int? = nil

    init(
        id: UUID,
        title: String,
        date: Date,
        subtitle: String? = nil,
        repeatsMonthly: Bool = false,
        monthlyDay: Int? = nil,
        repeatsWeekly: Bool = false,
        weeklyInterval: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.date = date
        self.subtitle = subtitle
        self.repeatsMonthly = repeatsMonthly
        self.monthlyDay = monthlyDay
        self.repeatsWeekly = repeatsWeekly
        self.weeklyInterval = weeklyInterval
    }
}

/// Constants used by the widget and the main app.
enum WidgetConstants {
    /// App Group identifier used for sharing data with the widget.
    /// Update this value to match the App Group you configure in Xcode.
    static let appGroupId: String = "group.kevin.countdown"
    static let selectedCountdownKey: String = "widgetCountdown"
    static let availableCountdownsKey: String = "widgetAvailableCountdowns"
    static let nextPublicHolidayInfoKey: String = "widgetNextPublicHoliday"
    static let nextLongWeekendInfoKey: String = "widgetNextLongWeekend"
}

extension WidgetCountdownConfig {
    /// Sentinel identifiers used to represent built-in default countdown options.
    /// These allow the app to distinguish them from user-created custom events.
    static let nextTimeOffID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    static let nextPublicHolidayID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    static let nextLongWeekendID = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
}

extension WidgetCountdownConfig {
    /// Saves a custom event as the widget's selected countdown.
    static func save(from event: CustomEvent) {
        let config = WidgetCountdownConfig(
            id: event.id,
            title: event.title,
            date: event.date,
            repeatsMonthly: event.repeatsMonthly,
            monthlyDay: event.monthlyDay,
            repeatsWeekly: event.repeatsWeekly,
            weeklyInterval: event.weeklyInterval
        )
        save(config)
    }

    /// Saves an arbitrary widget countdown configuration and refreshes timelines.
    static func save(_ config: WidgetCountdownConfig) {
        guard let data = try? JSONEncoder().encode(config) else { return }

        let defaults = UserDefaults(suiteName: WidgetConstants.appGroupId)
        defaults?.set(data, forKey: WidgetConstants.selectedCountdownKey)

        // Ask WidgetKit to refresh all timelines so the widget updates.
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Loads all countdowns that are available to be chosen in the widget configuration.
    /// These are mirrored from the main app's custom countdowns into the shared app group.
    static func loadAll() -> [WidgetCountdownConfig] {
        let defaults = UserDefaults(suiteName: WidgetConstants.appGroupId)
        guard let data = defaults?.data(forKey: WidgetConstants.availableCountdownsKey) else { return [] }
        if let configs = try? JSONDecoder().decode([WidgetCountdownConfig].self, from: data) {
            return configs
        } else if let single = load() {
            // Fallback: if only a single countdown was stored previously via save(from:),
            // expose it as the only available option so the picker still works.
            return [single]
        } else {
            return []
        }
    }

    /// Loads the currently selected widget countdown configuration, if any.
    static func load() -> WidgetCountdownConfig? {
        let defaults = UserDefaults(suiteName: WidgetConstants.appGroupId)
        guard let data = defaults?.data(forKey: WidgetConstants.selectedCountdownKey) else { return nil }
        return try? JSONDecoder().decode(WidgetCountdownConfig.self, from: data)
    }
}

/// Lightweight snapshot of holiday info shared to the widget via the App Group.
struct WidgetHolidayInfo: Codable, Equatable {
    let name: String
    let date: Date
}

extension WidgetHolidayInfo {
    static func loadNextPublicHoliday() -> WidgetHolidayInfo? {
        load(forKey: WidgetConstants.nextPublicHolidayInfoKey)
    }

    static func loadNextLongWeekend() -> WidgetHolidayInfo? {
        load(forKey: WidgetConstants.nextLongWeekendInfoKey)
    }

    @discardableResult
    static func storeNextPublicHoliday(_ info: WidgetHolidayInfo?) -> Bool {
        store(info, forKey: WidgetConstants.nextPublicHolidayInfoKey)
    }

    @discardableResult
    static func storeNextLongWeekend(_ info: WidgetHolidayInfo?) -> Bool {
        store(info, forKey: WidgetConstants.nextLongWeekendInfoKey)
    }

    private static func load(forKey key: String) -> WidgetHolidayInfo? {
        let defaults = UserDefaults(suiteName: WidgetConstants.appGroupId)
        guard let data = defaults?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WidgetHolidayInfo.self, from: data)
    }

    /// Stores `info` in the shared app group and returns true if the value changed.
    @discardableResult
    private static func store(_ info: WidgetHolidayInfo?, forKey key: String) -> Bool {
        let defaults = UserDefaults(suiteName: WidgetConstants.appGroupId)

        let existing: WidgetHolidayInfo? = {
            guard let data = defaults?.data(forKey: key) else { return nil }
            return try? JSONDecoder().decode(WidgetHolidayInfo.self, from: data)
        }()

        if existing == info { return false }

        if let info {
            guard let data = try? JSONEncoder().encode(info) else { return false }
            defaults?.set(data, forKey: key)
        } else {
            defaults?.removeObject(forKey: key)
        }

        return true
    }
}

// MARK: - Recurrence helpers shared with the widget

/// Calculates the next occurrence date for a recurring countdown, used by both the app and widget.
/// - Parameters:
///   - baseDate: Anchor date for the event (stores the original time and, for weekly recurrences, the weekday).
///   - referenceDate: "Now" – the point from which we want the next upcoming occurrence.
///   - repeatsMonthly: Whether the event repeats monthly.
///   - monthlyDay: Optional day of month (1...31). If nil, day from `baseDate` is used.
///   - repeatsWeekly: Whether the event repeats weekly.
///   - weeklyInterval: Number of weeks between occurrences (defaults to 1 when nil or < 1).
func nextRecurringDate(
    baseDate: Date,
    from referenceDate: Date = Date(),
    repeatsMonthly: Bool,
    monthlyDay: Int?,
    repeatsWeekly: Bool,
    weeklyInterval: Int?
) -> Date {
    let calendar = Calendar.singapore
    var candidates: [Date] = []

    // Non-recurring base date
    if !repeatsMonthly && !repeatsWeekly {
        if baseDate >= referenceDate {
            return baseDate
        } else {
            // For past non-recurring events, keep the original date so existing behaviour is preserved.
            return baseDate
        }
    }

    // Monthly recurrence: same time, specific day each month (clamped to month length).
    if repeatsMonthly {
        let day = monthlyDay ?? calendar.component(.day, from: baseDate)
        let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: baseDate)

        let startOfCurrentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: referenceDate)) ?? referenceDate

        for monthOffset in 0..<24 { // Look up to 2 years ahead to be safe.
            guard let monthStart = calendar.date(byAdding: .month, value: monthOffset, to: startOfCurrentMonth) else { continue }
            guard let range = calendar.range(of: .day, in: .month, for: monthStart) else { continue }
            let clampedDay = min(max(day, range.lowerBound), range.upperBound - 1)

            var comps = calendar.dateComponents([.year, .month], from: monthStart)
            comps.day = clampedDay
            comps.hour = timeComponents.hour
            comps.minute = timeComponents.minute
            comps.second = timeComponents.second

            if let candidate = calendar.date(from: comps), candidate >= referenceDate {
                candidates.append(candidate)
                break
            }
        }
    }

    // Weekly recurrence: every N weeks using baseDate as the anchor.
    if repeatsWeekly {
        let intervalWeeks = max(weeklyInterval ?? 1, 1)
        let secondsPerInterval = Double(intervalWeeks) * 7 * 24 * 60 * 60

        var candidate = baseDate
        if candidate < referenceDate {
            let diffSeconds = referenceDate.timeIntervalSince(candidate)
            let intervalsPassed = Int(ceil(diffSeconds / secondsPerInterval))
            if let advanced = calendar.date(byAdding: .day, value: intervalsPassed * intervalWeeks * 7, to: baseDate) {
                candidate = advanced
            }
        }

        if candidate >= referenceDate {
            candidates.append(candidate)
        }
    }

    // If we never found a candidate, fall back to baseDate to avoid surprises.
    return candidates.min() ?? baseDate
}

extension WidgetCountdownConfig {
    /// Returns the next date the widget should count down to, including recurrence rules.
    func nextTargetDate(from referenceDate: Date = Date()) -> Date {
        nextRecurringDate(
            baseDate: date,
            from: referenceDate,
            repeatsMonthly: repeatsMonthly,
            monthlyDay: monthlyDay,
            repeatsWeekly: repeatsWeekly,
            weeklyInterval: weeklyInterval
        )
    }
}
