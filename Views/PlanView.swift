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
        
        // Generate recommendations for each future holiday
        let recs = uniqueFutureHolidays.compactMap { holiday in
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
        
        return uniqueRecs
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
                        Text("Strategically stack annual leave with upcoming public holidays to maximise your time off.")
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
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter
    }()
    
    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()
    
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
                
                // Total days badge
                Text("\(recommendation.totalDaysOff) days")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue)
                    .clipShape(Capsule())
            }
            
            // Leave dates
            VStack(alignment: .leading, spacing: 8) {
                Text("Take leave on:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack {
                    ForEach(recommendation.recommendedLeaveDates, id: \.self) { date in
                        Text(Self.shortDateFormatter.string(from: date))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange)
                            .clipShape(Capsule())
                    }
                }
            }
            
            // Reasoning
            Text(recommendation.reasoning)
                .font(.body)
                .foregroundColor(.primary)
                .padding(.top, 4)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

#Preview {
    PlanView()
        .environmentObject(CountdownModel())
}
