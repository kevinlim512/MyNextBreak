import Foundation

extension Calendar {
    /// Returns a Calendar instance configured for Singapore timezone
    /// Used throughout the app to ensure consistent date calculations
    static var singapore: Calendar {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "Asia/Singapore") ?? TimeZone.current
        return calendar
    }
    
    /// Finds the next non-working day based on a custom work schedule
    /// workingDays array: [Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, Sunday]
    /// Returns the date if today is already a non-working day, or the next non-working day
    func nextDayOff(startingAfter date: Date, workingDays: [Bool]) -> Date? {
        var currentDate = self.startOfDay(for: date)

        // First check if today is already a non-working day
        let todayWeekday = self.component(.weekday, from: currentDate)
        let todayWorkIndex = (todayWeekday + 5) % 7 // Convert to Monday=0, Sunday=6

        if !workingDays[todayWorkIndex] {
            return currentDate // Return today if it's already a non-working day
        }

        // If today is a working day, search for the next non-working day
        for _ in 1...7 { // Check up to 7 days ahead
            guard let nextDate = self.date(byAdding: .day, value: 1, to: currentDate) else {
                return nil
            }
            currentDate = nextDate
            let weekday = self.component(.weekday, from: currentDate)
            let workIndex = (weekday + 5) % 7

            if !workingDays[workIndex] {
                return currentDate
            }
        }

        return nil
    }
} 