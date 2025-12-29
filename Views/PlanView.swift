//
//  PlanView.swift
//  Countdown App
//
//  Created by Kevin on 25/7/25.
//

import SwiftUI

/// View that displays leave recommendations for long weekends
/// Shows opportunities where users can take leave to create 4+ day long weekends
struct PlanView: View {
    // MARK: - Properties
    @EnvironmentObject var model: CountdownModel
    @AppStorage("workingDaysArray") private var workingDaysArray: String = "true,true,true,true,true,false,false"
    
    // MARK: - Computed Properties
    private var workingDays: [Bool] {
        workingDaysArray.split(separator: ",").map { $0 == "true" }
    }
    
    private var leaveRecommendations: [LeaveRecommendation] {
        guard workingDays.count == 7 else { return [] }
        
        let now = Date()
        
        // Get future holidays from the model's holiday store
        let baseFutureHolidays = model.store.holidays.filter { $0.date > now }

        // Build an effective holiday list for planning:
        // - If a holiday falls on Sunday, include the following Monday as a holiday (observed) and drop the Sunday entry.
        // - If a holiday falls on Saturday AND Saturday is a non-working day, exclude it from planning.
        // - Avoid duplicate dates.
        let calendar = Calendar.singapore
        var dateSeen: Set<Date> = []
        var effectiveFutureHolidays: [Holiday] = []
        for h in baseFutureHolidays.sorted(by: { $0.date < $1.date }) {
            let wd = calendar.component(.weekday, from: h.date)
            let start = calendar.startOfDay(for: h.date)
            if wd == 1 { // Sunday -> use Monday as observed
                if let monday = calendar.date(byAdding: .day, value: 1, to: start) {
                    let mondayStart = calendar.startOfDay(for: monday)
                    if !dateSeen.contains(mondayStart) {
                        dateSeen.insert(mondayStart)
                        effectiveFutureHolidays.append(Holiday(name: h.name, date: mondayStart))
                    }
                }
                // skip the Sunday entry
                continue
            } else if wd == 7 { // Saturday
                let saturdayNonWorking = workingDays.count == 7 ? !workingDays[5] : true
                if saturdayNonWorking {
                    // skip this holiday if Saturday is already non-working
                    continue
                }
            }

            if !dateSeen.contains(start) {
                dateSeen.insert(start)
                effectiveFutureHolidays.append(Holiday(name: h.name, date: start))
            }
        }

        // De-duplicate holidays by (name + date at startOfDay) to avoid repeated suggestions
        var seen: Set<String> = []
        let uniqueFutureHolidays: [Holiday] = effectiveFutureHolidays.filter { h in
            let key = "\(h.name)|\(calendar.startOfDay(for: h.date))"
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }
        
        // Combine contiguous multi-day holidays with the same name (e.g., Chinese New Year)
        // Keep only the first day as the representative to avoid duplicate cards
        let sortedByNameDate = uniqueFutureHolidays.sorted { lhs, rhs in
            if lhs.name == rhs.name { return lhs.date < rhs.date }
            return lhs.name < rhs.name
        }
        var combinedFutureHolidays: [Holiday] = []
        var idx = 0
        while idx < sortedByNameDate.count {
            let startHoliday = sortedByNameDate[idx]
            var j = idx
            while j + 1 < sortedByNameDate.count,
                  sortedByNameDate[j + 1].name == startHoliday.name {
                let d1 = calendar.startOfDay(for: sortedByNameDate[j].date)
                let d2 = calendar.startOfDay(for: sortedByNameDate[j + 1].date)
                if let diff = calendar.dateComponents([.day], from: d1, to: d2).day, diff == 1 {
                    j += 1
                } else {
                    break
                }
            }
            combinedFutureHolidays.append(startHoliday)
            idx = j + 1
        }

        // Generate recommendations for each combined future holiday
        let recs = combinedFutureHolidays.compactMap { holiday in
            LeaveRecommendation.createRecommendation(
                for: holiday,
                workingDays: workingDays,
                holidays: effectiveFutureHolidays
            )
        }
        
        // Defensive de-duplication of recommendations by holiday (name + date)
        var recSeen: Set<String> = []
        let uniqueRecs = recs.filter { rec in
            let key = "\(rec.holiday.name)|\(calendar.startOfDay(for: rec.holiday.date))"
            if recSeen.contains(key) { return false }
            recSeen.insert(key)
            return true
        }
        
        // Present recommendations in chronological order (soonest first).
        // This avoids cases like New Year's Day appearing at the bottom due to upstream name-based sorting.
        return uniqueRecs.sorted { lhs, rhs in
            let l = calendar.startOfDay(for: lhs.holiday.date)
            let r = calendar.startOfDay(for: rhs.holiday.date)
            if l != r { return l < r }
            return lhs.holiday.name < rhs.holiday.name
        }
    }
    
    var body: some View {
        Group {
            if leaveRecommendations.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)

                    Text("No Opportunities Yet")
                        .font(.title3)
                        .fontWeight(.semibold)

                    Text("We'll surface 4+ day long weekends here once new public holidays are available.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Text("Strategically stack your annual leave with upcoming public holidays to maximise your time off.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)

                        ForEach(leaveRecommendations) { recommendation in
                            LeaveRecommendationCard(recommendation: recommendation)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(UIColor.systemGroupedBackground))
    }
}

/// Card view for displaying a single leave recommendation
struct LeaveRecommendationCard: View {
    let recommendation: LeaveRecommendation
    @AppStorage("workingDaysArray") private var workingDaysArray: String = "true,true,true,true,true,false,false"
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter
    }()

    private static let leaveDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()
    
    // Removed short date formatter as chips are no longer shown
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Holiday header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(recommendation.holiday.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(Self.dateFormatter.string(from: recommendation.holiday.date))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if recommendation.options.count == 1 {
                    Text("\(recommendation.maxTotalDaysOff) days")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue)
                        .clipShape(Capsule())
                }
            }

            VStack(alignment: .leading, spacing: 16) {
                ForEach(Array(recommendation.options.enumerated()), id: \.element.id) { index, option in
                    VStack(alignment: .leading, spacing: 12) {
                        if recommendation.options.count > 1 {
                            HStack {
                                Text("Option \(index + 1)")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)

                                Spacer()

                                Text("\(option.blockDays.count) days")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue)
                                    .clipShape(Capsule())
                            }
                        }

                        WeekStripView(
                            holiday: recommendation.holiday,
                            leaveDates: option.recommendedLeaveDates,
                            workingDays: workingDaysArray.split(separator: ",").map { $0 == "true" },
                            blockDays: option.blockDays,
                            holidayDates: option.holidayDates
                        )
                        .padding(.top, 4)

                        Text(reasoning(for: option))
                            .font(.body)
                            .foregroundColor(.primary)
                    }

                    if index < recommendation.options.count - 1 {
                        Divider()
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }

    private func reasoning(for option: LeaveOption) -> String {
        let leaveDatesText = option.recommendedLeaveDates
            .sorted()
            .map { Self.leaveDateFormatter.string(from: $0) }
            .joined(separator: ", ")
        return "Take leave on \(leaveDatesText) to enjoy a \(option.blockDays.count)-day long weekend around \(recommendation.holiday.name)"
    }
}

/// Compact Monday–Sunday week strip highlighting the holiday, non-working days, and leave suggestion(s)
private struct WeekStripView: View {
    let holiday: Holiday
    let leaveDates: [Date]
    let workingDays: [Bool] // Monday..Sunday
    let blockDays: [Date]
    let holidayDates: [Date]

    private let calendar = Calendar.singapore

    private var weekDays: [Date] {
        let day = calendar.startOfDay(for: holiday.date)
        let weekday = calendar.component(.weekday, from: day)
        // Convert to Monday=0..Sunday=6
        let workIndex = (weekday + 5) % 7
        guard let monday = calendar.date(byAdding: .day, value: -workIndex, to: day) else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: monday).map { calendar.startOfDay(for: $0) } }
    }

    private var previousWeekDays: [Date] {
        guard let currentMonday = weekDays.first,
              let prevMonday = calendar.date(byAdding: .day, value: -7, to: currentMonday) else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: prevMonday).map { calendar.startOfDay(for: $0) } }
    }

    private var nextWeekDays: [Date] {
        guard let currentMonday = weekDays.first,
              let nextMonday = calendar.date(byAdding: .day, value: 7, to: currentMonday) else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: nextMonday).map { calendar.startOfDay(for: $0) } }
    }

    private var needsPreviousWeek: Bool {
        guard let currentMonday = weekDays.first else { return false }
        return blockDays.contains { calendar.startOfDay(for: $0) < currentMonday }
    }

    private var needsNextWeek: Bool {
        guard let currentSunday = weekDays.last else { return false }
        return blockDays.contains { calendar.startOfDay(for: $0) > currentSunday }
    }

    private func isSameDay(_ a: Date, _ b: Date) -> Bool {
        calendar.isDate(a, inSameDayAs: b)
    }

    private func isNonWorkingDay(_ date: Date) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        let idx = (weekday + 5) % 7
        guard workingDays.indices.contains(idx) else { return false }
        return !workingDays[idx]
    }

    private func isLeave(_ date: Date) -> Bool {
        leaveDates.contains { isSameDay($0, date) }
    }

    private func weekdaySymbol(for date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_SG")
        f.dateFormat = "E" // Mon, Tue, ...
        return f.string(from: date)
    }

    private func dayNumber(_ date: Date) -> String {
        let d = calendar.component(.day, from: date)
        return String(d)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if needsPreviousWeek {
                HStack(spacing: 8) {
                    ForEach(previousWeekDays, id: \.self) { day in
                        dayCell(day)
                    }
                }
            }

            HStack(spacing: 8) {
                ForEach(weekDays, id: \.self) { day in
                    dayCell(day)
                }
            }

            if needsNextWeek {
                HStack(spacing: 8) {
                    ForEach(nextWeekDays, id: \.self) { day in
                        dayCell(day)
                    }
                }
            }

            // Legend
            HStack(spacing: 12) {
                LegendSwatch(color: .blue, label: "Holiday")
                LegendSwatch(color: .orange, label: "Take Leave")
                LegendSwatch(color: .red, label: "Non-working")
            }
            .font(.caption2)
            .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private func dayCell(_ day: Date) -> some View {
        let markHoliday = holidayDates.contains { isSameDay($0, day) } || isSameDay(day, holiday.date)
        let leave = isLeave(day)
        let nonWorking = isNonWorkingDay(day)

        VStack(spacing: 4) {
            // Arrow suggesting leave day
            Group {
                if leave {
                    Image(systemName: "arrow.down")
                        .font(.caption2)
                        .foregroundColor(.orange)
                } else {
                    Color.clear.frame(height: 0)
                }
            }

            VStack(spacing: 2) {
                Text(weekdaySymbol(for: day))
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Text(dayNumber(day))
                    .font(.caption)
                    .fontWeight(markHoliday ? .bold : .regular)
                    .foregroundColor(.white)
                    .frame(width: 32, height: 24)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                markHoliday ? Color.blue : (leave ? Color.orange : (nonWorking ? Color.red : Color.gray.opacity(0.35)))
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.black.opacity(0.05), lineWidth: 0.5)
                    )
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityLabel(Text("\(weekdaySymbol(for: day)) \(dayNumber(day))" + (markHoliday ? ", Holiday" : (leave ? ", Leave" : (nonWorking ? ", Non-working" : "")))))
    }
}

private struct LegendSwatch: View {
    let color: Color
    let label: String
    var body: some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 14, height: 10)
            Text(label)
        }
    }
}

#Preview {
    PlanView()
        .environmentObject(CountdownModel())
}
