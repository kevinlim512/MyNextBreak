//
//  LeaveRecommendation.swift
//  Countdown App
//
//  Created by Kevin on 25/7/25.
//

import Foundation

/// Represents a leave recommendation for creating a long weekend
struct LeaveRecommendation: Identifiable {
    let id = UUID()
    let holiday: Holiday                    // The public holiday that triggers this recommendation
    let recommendedLeaveDates: [Date]       // Dates the user should take leave
    let totalDaysOff: Int                   // Total consecutive days off (including holiday and weekends)
    let reasoning: String                   // Human-readable explanation
    
    /// Creates a leave recommendation for a specific holiday scenario
    /// - Parameters:
    ///   - holiday: The public holiday
    ///   - workingDays: User's working days configuration (Monday-Sunday)
    ///   - holidays: All available holidays for context
    /// - Returns: Leave recommendation if a long weekend opportunity exists
    static func createRecommendation(
        for holiday: Holiday,
        workingDays: [Bool],
        holidays: [Holiday]
    ) -> LeaveRecommendation? {
        let calendar = Calendar.singapore
        let maxLeaveDays = 2
        let maxSpan = 6
        let holidayDate = calendar.startOfDay(for: holiday.date)
        
        func isHolidayDate(_ date: Date) -> Bool {
            holidays.contains { calendar.isDate($0.date, inSameDayAs: date) }
        }
        
        func isNonWorkingDay(_ date: Date) -> Bool {
            let weekday = calendar.component(.weekday, from: date)
            let workIndex = (weekday + 5) % 7 // Monday=0, Sunday=6
            return !workingDays[workIndex]
        }
        
        func isAutoOff(_ date: Date) -> Bool {
            isHolidayDate(date) || isNonWorkingDay(date)
        }

        // If the holiday already sits inside a 3+ day auto-off block (e.g. Sat–Mon),
        // we should NOT suggest taking additional leave around it.
        // Expand from the holiday outwards while days are auto-off.
        var autoOffBlock: [Date] = [holidayDate]
        // Expand backwards
        var cursor = holidayDate
        while let prev = calendar.date(byAdding: .day, value: -1, to: cursor), isAutoOff(prev) {
            autoOffBlock.insert(prev, at: 0)
            cursor = prev
        }
        // Expand forwards
        cursor = holidayDate
        while let next = calendar.date(byAdding: .day, value: 1, to: cursor), isAutoOff(next) {
            autoOffBlock.append(next)
            cursor = next
        }
        if autoOffBlock.count >= 3 {
            // Already a long weekend without leave; do not recommend extras.
            return nil
        }

        var windowDates: [Date] = []
        for offset in (-maxSpan)...maxSpan {
            if let candidate = calendar.date(byAdding: .day, value: offset, to: holidayDate) {
                windowDates.append(calendar.startOfDay(for: candidate))
            }
        }
        
        guard let holidayIndex = windowDates.firstIndex(where: { calendar.isDate($0, inSameDayAs: holidayDate) }) else {
            return nil
        }
        
        struct Candidate {
            let block: [Date]
            let leaveDays: [Date]
        }
        
        func isBetter(_ lhs: Candidate, than rhs: Candidate) -> Bool {
            if lhs.leaveDays.count != rhs.leaveDays.count {
                return lhs.leaveDays.count < rhs.leaveDays.count
            }
            if lhs.block.count != rhs.block.count {
                return lhs.block.count > rhs.block.count
            }
            guard let lhsStart = lhs.block.first, let rhsStart = rhs.block.first else {
                return false
            }
            return lhsStart < rhsStart
        }
        
        var bestCandidate: Candidate?
        
        for startIndex in 0...holidayIndex {
            for endIndex in holidayIndex..<windowDates.count {
                let block = Array(windowDates[startIndex...endIndex])
                let totalDays = block.count
                guard totalDays >= 4 else { continue }
                let leaveDays = block.filter { !isAutoOff($0) }
                guard !leaveDays.isEmpty, leaveDays.count <= maxLeaveDays else { continue }
                let autoOffCount = block.filter { isAutoOff($0) }.count
                guard autoOffCount >= 2 else { continue }
                let candidate = Candidate(block: block, leaveDays: leaveDays)
                if let currentBest = bestCandidate {
                    if isBetter(candidate, than: currentBest) {
                        bestCandidate = candidate
                    }
                } else {
                    bestCandidate = candidate
                }
            }
        }
        
        guard let chosen = bestCandidate else {
            return nil
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d"
        let leaveDatesText = chosen.leaveDays
            .sorted()
            .map { dateFormatter.string(from: $0) }
            .joined(separator: ", ")
        
        let reasoning = "Take leave on \(leaveDatesText) to enjoy a \(chosen.block.count)-day long weekend around \(holiday.name)"
        
        return LeaveRecommendation(
            holiday: holiday,
            recommendedLeaveDates: chosen.leaveDays.sorted(),
            totalDaysOff: chosen.block.count,
            reasoning: reasoning
        )
    }
}
