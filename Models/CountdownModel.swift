//
//  CountdownModel.swift
//  Countdown App
//
//  Created by Kevin on 25/7/25.
//

import Foundation
import Combine
import SwiftUI



/// Main data model that manages countdown calculations and updates
/// Handles non-working days, holiday, and long weekend countdown logic
class CountdownModel: ObservableObject {
    // MARK: - Published Properties
    @Published var nextNonWorkingDate: Date = Date()        // Next non-working day date
    @Published var nextHoliday: Holiday?                    // Next public holiday with full details
    @Published var nextLongWeekendHoliday: Holiday?         // Next holiday that creates a long weekend

    // MARK: - Private Properties
    // Use a shared HolidayStore so all views/components share the same holiday data
    let store = HolidayStore.shared
    private var timer: Timer?                               // Timer for periodic updates

    // Listen to AppStorage changes for working days configuration
    @AppStorage("workingDaysArray") private var workingDaysArray: String = "true,true,true,true,true,false,false"
    private var cancellables = Set<AnyCancellable>()        // Combine cancellables

    init() {
        // Initialize with current targets
        updateTargets()
        
        // Set up timer to update countdowns every minute
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.updateTargets()
        }

        // Listen for AppStorage changes (working days configuration)
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateTargets()
            }
            .store(in: &cancellables)
            
        // Listen for holiday store updates
        store.$holidays
            .sink { [weak self] _ in
                self?.updateTargets()
            }
            .store(in: &cancellables)
    }

    deinit {
        timer?.invalidate()
    }

    /// Counts consecutive non-working days starting from a given date
    /// Includes both configured non-working days and public holidays
    private func countConsecutiveOffDays(startingFrom date: Date, workingDays: [Bool], holidays: [Holiday]) -> Int {
        let calendar = Calendar.singapore
        var currentDate = calendar.startOfDay(for: date)
        var consecutiveDays = 0
        
        // Check up to 7 days to find the consecutive streak
        for _ in 0..<7 {
            let weekday = calendar.component(.weekday, from: currentDate)
            let workIndex = (weekday + 5) % 7  // Convert to Monday=0, Sunday=6
            
            // Check if this day is a non-working day OR a holiday
            let isNonWorkingDay = !workingDays[workIndex]
            let isHoliday = holidays.contains { holiday in
                calendar.isDate(holiday.date, inSameDayAs: currentDate)
            }
            
            if isNonWorkingDay || isHoliday {
                consecutiveDays += 1
                guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
                currentDate = nextDate
            } else {
                break // Streak broken by a working day
            }
        }
        
        return consecutiveDays
    }

    /// Updates all countdown targets based on current date and configuration
    /// Called periodically and when settings change
    private func updateTargets() {
        let now = Date()
        let calendar = Calendar.singapore
        guard workingDaysArray.split(separator: ",").count == 7 else { return }
        let workingDays = workingDaysArray.split(separator: ",").map { $0 == "true" }

        // 1) Calculate next non-working day
        if let dayOff = calendar.nextDayOff(startingAfter: now, workingDays: workingDays) {
            nextNonWorkingDate = dayOff
        } else {
            nextNonWorkingDate = now
        }

        // 2) Filter holidays to only future dates
        let futureHolidays = store.holidays.filter { $0.date > now }
        
        // Debug logging for holiday data
        print("🔍 CountdownModel: Total holidays loaded: \(store.holidays.count)")
        print("🔍 CountdownModel: Future holidays: \(futureHolidays.count)")
        if !futureHolidays.isEmpty {
            print("🔍 CountdownModel: First future holiday: \(futureHolidays.first?.name ?? "Unknown") on \(futureHolidays.first?.date ?? Date())")
        }

        // 3) Set next public holiday (first future holiday)
        nextHoliday = futureHolidays.first

        // 4) Find next long weekend (holiday with 3+ consecutive off days)
        nextLongWeekendHoliday = futureHolidays.first { holiday in
            // Find the start of the potential long weekend by looking backwards
            var startDate = holiday.date
            let calendar = Calendar.singapore
            
            // Look backwards to find the start of consecutive off days
            while true {
                guard let previousDay = calendar.date(byAdding: .day, value: -1, to: startDate) else { break }
                let prevWeekday = calendar.component(.weekday, from: previousDay)
                let prevWorkIndex = (prevWeekday + 5) % 7
                
                let isPrevNonWorkingDay = !workingDays[prevWorkIndex]
                let isPrevHoliday = futureHolidays.contains { h in
                    calendar.isDate(h.date, inSameDayAs: previousDay)
                }
                
                if isPrevNonWorkingDay || isPrevHoliday {
                    startDate = previousDay
                } else {
                    break
                }
            }
            
            // Count consecutive off days from the start
            let consecutiveOffDays = countConsecutiveOffDays(
                startingFrom: startDate, 
                workingDays: workingDays, 
                holidays: futureHolidays
            )
            
            // Debug logging for long weekend calculation
            print("🔍 CountdownModel: Checking holiday '\(holiday.name)' for long weekend - consecutive off days: \(consecutiveOffDays)")
            
            // Must have 3 or more consecutive off days to be a long weekend
            return consecutiveOffDays >= 3
        }
        
        // Fallback: if no long weekend found, use the next holiday
        if nextLongWeekendHoliday == nil && !futureHolidays.isEmpty {
            nextLongWeekendHoliday = futureHolidays.first
            print("🔍 CountdownModel: Using fallback - next holiday as long weekend: \(futureHolidays.first?.name ?? "Unknown")")
        }
        
        // Debug logging for final result
        if let longWeekend = nextLongWeekendHoliday {
            print("🔍 CountdownModel: Found long weekend: \(longWeekend.name) on \(longWeekend.date)")
        } else {
            print("🔍 CountdownModel: No long weekend found")
        }
    }

    /// Formats a countdown interval as a human-readable string
    /// Returns format like "3d 4h 12m" or celebratory messages for current/past dates
    func countdown(to date: Date) -> String {
        let diff = Int(date.timeIntervalSinceNow)
        
        // Handle current day or past dates with celebratory messages
        let calendar = Calendar.singapore
        if calendar.isDate(date, inSameDayAs: Date()) && diff <= 0 {
            return "Enjoy!"  // It's the target day!
        } else if diff <= 0 {
            return "Now!"    // Past the target date
        }

        // Calculate days, hours, and minutes
        let days    = diff / 86_400      // 86,400 seconds in a day
        let hours   = (diff % 86_400) / 3_600  // 3,600 seconds in an hour
        let minutes = (diff % 3_600) / 60      // 60 seconds in a minute

        return "\(days)d \(hours)h \(minutes)m"
    }
}
