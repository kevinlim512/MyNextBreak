import Foundation

struct CustomEvent: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var date: Date
    // Optional style index for gradient/background selection
    var styleIndex: Int?

    /// Recurrence configuration
    /// - `repeatsMonthly`: when true, the event repeats every month on `monthlyDay`
    /// - `monthlyDay`: 1...31; if nil, the day from `date` is used
    /// - `repeatsWeekly`: when true, the event repeats every `weeklyInterval` weeks
    ///   using the weekday and time from `date` as the anchor
    /// - `weeklyInterval`: number of weeks between occurrences (defaults to 1)
    var repeatsMonthly: Bool = false
    var monthlyDay: Int? = nil
    var repeatsWeekly: Bool = false
    var weeklyInterval: Int? = nil

    init(
        id: UUID = UUID(),
        title: String,
        date: Date,
        styleIndex: Int? = nil,
        repeatsMonthly: Bool = false,
        monthlyDay: Int? = nil,
        repeatsWeekly: Bool = false,
        weeklyInterval: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.date = date
        self.styleIndex = styleIndex
        self.repeatsMonthly = repeatsMonthly
        self.monthlyDay = monthlyDay
        self.repeatsWeekly = repeatsWeekly
        self.weeklyInterval = weeklyInterval
    }
}

extension CustomEvent {
    /// Returns the next target date for this event, taking into account its recurrence settings.
    /// For non-recurring events, this simply returns `date` (or the next future occurrence if in the past).
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
