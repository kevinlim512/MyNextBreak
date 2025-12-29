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
    @State private var styleIndex: Int
    @State private var showWeeklyDatePicker: Bool = false
    private var weeklyDateBackground: Color {
        Color(.tertiarySystemFill)
    }

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
        _styleIndex = State(initialValue: event.styleIndex ?? 0)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Title")) {
                    TextField("Enter a title", text: $title)
                        .textInputAutocapitalization(.words)
                }

                Section(header: Text("Date & Time")) {
                    VStack(alignment: .leading, spacing: 4) {
                        if repeatsWeekly {
                            Text("Start of Countdown:")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                        HStack(spacing: 12) {
                            if !repeatsMonthly {
                                Button {
                                    showWeeklyDatePicker = true
                                } label: {
                                    Text(date, format: .dateTime.day().month().year())
                                        .foregroundColor(.primary)
                                        .padding(.vertical, 6)
                                        .padding(.horizontal, 12)
                                        .background(
                                            Capsule()
                                                .fill(weeklyDateBackground)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                            DatePicker("", selection: $date, displayedComponents: [.hourAndMinute])
                                .labelsHidden()
                                .datePickerStyle(.compact)
                            Spacer(minLength: 0)
                        }
                    }

                    Toggle("Repeat Every Month", isOn: $repeatsMonthly)
                        .onChange(of: repeatsMonthly) { _, isOn in
                            if isOn {
                                repeatsWeekly = false
                            }
                        }

                    if repeatsMonthly {
                        VStack(spacing: 0) {
                            Text("Day of Month")
                                .frame(maxWidth: .infinity, alignment: .center)
                            Picker("Day of Month", selection: $monthlyDay) {
                                ForEach(1...31, id: \.self) { day in
                                    Text("\(day)")
                                        .tag(day)
                                }
                            }
                            .pickerStyle(.wheel)
                        }
                    }

                    Toggle("Repeat Every Week", isOn: $repeatsWeekly)
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

                Section(header: Text("Card Style")) {
                    let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(Array(AppGradients.customEvent.enumerated()), id: \.offset) { idx, grad in
                            ZStack {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(grad)
                                    .frame(height: 44)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(styleIndex == idx ? Color.blue : Color.clear, lineWidth: 3)
                                    )
                                if styleIndex == idx {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.white)
                                        .shadow(radius: 3)
                                }
                            }
                            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .onTapGesture { styleIndex = idx }
                        }
                    }
                    .padding(.vertical, 4)
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
            .navigationDestination(isPresented: $showWeeklyDatePicker) {
                WeeklyDatePickerView(date: $date, weekday: repeatsWeekly ? weeklyDayOfWeek : nil)
            }
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
                        updated.styleIndex = styleIndex
                        onComplete(.updated(updated))
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onChange(of: repeatsWeekly) { _, isOn in
                if isOn {
                    date = alignedWeeklyDate(from: date, weekday: weeklyDayOfWeek)
                }
            }
            .onChange(of: weeklyDayOfWeek) { _, newValue in
                if repeatsWeekly {
                    date = alignedWeeklyDate(from: date, weekday: newValue)
                }
            }
        }
    }

    private func alignedWeeklyDate(from date: Date, weekday: Int) -> Date {
        let calendar = Calendar.singapore
        let currentWeekday = calendar.component(.weekday, from: date)
        guard currentWeekday != weekday else { return date }
        let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: date)
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.weekday = weekday
        components.hour = timeComponents.hour
        components.minute = timeComponents.minute
        components.second = timeComponents.second
        return calendar.nextDate(
            after: date.addingTimeInterval(-60),
            matching: components,
            matchingPolicy: .nextTimePreservingSmallerComponents
        ) ?? date
    }
}
