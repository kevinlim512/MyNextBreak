import SwiftUI

/// Edit screen for a custom countdown event
struct EditCustomCountdownView: View {
    enum Result {
        case updated(CustomEvent)
        case deleted(CustomEvent)
        case cancelled
    }

    let event: CustomEvent
    var onComplete: (Result) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var date: Date
    @State private var repeatsMonthly: Bool
    @State private var monthlyDay: Int
    @State private var repeatsWeekly: Bool
    @State private var weeklyDayOfWeek: Int
    @State private var weeklyInterval: Int

    init(event: CustomEvent, onComplete: @escaping (Result) -> Void) {
        self.event = event
        self.onComplete = onComplete
        _title = State(initialValue: event.title)
        _date = State(initialValue: event.date)
        _repeatsMonthly = State(initialValue: event.repeatsMonthly)
        _monthlyDay = State(initialValue: event.monthlyDay ?? Calendar.singapore.component(.day, from: event.date))
        _repeatsWeekly = State(initialValue: event.repeatsWeekly)
        _weeklyDayOfWeek = State(initialValue: Calendar.singapore.component(.weekday, from: event.date))
        _weeklyInterval = State(initialValue: max(event.weeklyInterval ?? 1, 1))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Title")) {
                    TextField("Enter a title", text: $title)
                        .textInputAutocapitalization(.words)
                }

                Section(header: Text("Date & Time")) {
                    DatePicker("", selection: $date, displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                }

                Section(header: Text("Repeat")) {
                    Toggle("Every Month", isOn: $repeatsMonthly)
                        .onChange(of: repeatsMonthly) { _, isOn in
                            if isOn {
                                repeatsWeekly = false
                            }
                        }

                    if repeatsMonthly {
                        VStack(alignment: .leading, spacing: 4) {
                            Divider()
                                .padding(.top, 0)
                                .padding(.bottom, 12)
                            Text("Day of Month")
                        }
                        .listRowSeparator(.hidden)
                        Picker("Day of Month", selection: $monthlyDay) {
                            ForEach(1...31, id: \.self) { day in
                                Text("\(day)")
                                    .tag(day)
                            }
                        }
                        .pickerStyle(.wheel)
                    }

                    Toggle("Every Week", isOn: $repeatsWeekly)
                        .onChange(of: repeatsWeekly) { _, isOn in
                            if isOn {
                                repeatsMonthly = false
                            }
                        }

                    if repeatsWeekly {
                        Picker("Day of Week", selection: $weeklyDayOfWeek) {
                            let symbols = Calendar.singapore.weekdaySymbols
                            ForEach(1...symbols.count, id: \.self) { index in
                                Text(symbols[index - 1])
                                    .tag(index)
                            }
                        }

                        Stepper("Every \(weeklyInterval) week(s)", value: $weeklyInterval, in: 1...8)
                    }
                }

                Section {
                    Button(role: .destructive) {
                        onComplete(.deleted(event))
                        dismiss()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Delete Countdown")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Edit Countdown")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { onComplete(.cancelled); dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        var updated = event
                        updated.title = trimmed
                        // Adjust anchor date for weekly recurrence.
                        let calendar = Calendar.singapore
                        var anchorDate = date

                        if repeatsWeekly {
                            let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: date)
                            var components = calendar.dateComponents([.year, .month, .day], from: date)
                            components.weekday = weeklyDayOfWeek
                            components.hour = timeComponents.hour
                            components.minute = timeComponents.minute
                            components.second = timeComponents.second

                            if let next = calendar.nextDate(
                                after: date.addingTimeInterval(-60),
                                matching: components,
                                matchingPolicy: .nextTimePreservingSmallerComponents
                            ) {
                                anchorDate = next
                            }
                        }

                        updated.date = anchorDate
                        updated.repeatsMonthly = repeatsMonthly
                        updated.monthlyDay = repeatsMonthly ? monthlyDay : nil
                        updated.repeatsWeekly = repeatsWeekly
                        updated.weeklyInterval = repeatsWeekly ? weeklyInterval : nil
                        onComplete(.updated(updated))
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
