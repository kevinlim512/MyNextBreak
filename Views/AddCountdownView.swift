import SwiftUI

/// Screen to add a custom countdown with title presets and date/time.
struct AddCountdownView: View {
    enum TitlePreset: String, CaseIterable, Identifiable {
        case holiday = "Holiday"
        case payday = "Pay Day"

        var id: String { rawValue }
        var iconName: String {
            switch self {
            case .holiday: return "calendar"
            case .payday: return "creditcard"
            }
        }
    }

    @Environment(\.dismiss) private var dismiss

    // Inputs
    @State private var title: String = ""
    @State private var selectedPreset: TitlePreset? = nil
    @State private var date: Date = Calendar.singapore.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    // Recurrence
    @State private var repeatsMonthly: Bool = false
    @State private var monthlyDay: Int = Calendar.singapore.component(.day, from: Date())
    @State private var repeatsWeekly: Bool = false
    @State private var weeklyDayOfWeek: Int = Calendar.singapore.component(.weekday, from: Date())
    @State private var weeklyInterval: Int = 1
    @State private var styleIndex: Int = 0

    // Save handler injected by caller
    var onSave: (CustomEvent) -> Void

    var body: some View {
        NavigationStack {
            Form {
                // Title input
                Section(header: Text("Title")) {
                    TextField("Enter a title", text: $title)
                        .textInputAutocapitalization(.words)
                }

                // Presets styled like SetupView's list with trailing checkmark
                Section(header:
                            HStack(spacing: 8) {
                                Image(systemName: "slider.horizontal.3")
                                    .foregroundColor(.orange)
                                Text("Title Presets")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .textCase(nil)
                            }
                            .padding(.vertical, 6)
                ) {
                    VStack(spacing: 0) {
                        ForEach(TitlePreset.allCases) { preset in
                            Button {
                                if selectedPreset == preset {
                                    // Unselect and clear title
                                    selectedPreset = nil
                                    title = ""
                                } else {
                                    selectedPreset = preset
                                    title = preset.rawValue
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    // Checkbox indicator (visual change from radio to checkbox)
                                    Image(systemName: selectedPreset == preset ? "checkmark.square.fill" : "square")
                                        .foregroundColor(selectedPreset == preset ? .blue : .secondary)
                                        .imageScale(.large)
                                    // Native icon + label
                                    Image(systemName: preset.iconName)
                                        .imageScale(.large)
                                        .foregroundColor(.primary)
                                    Text(preset.rawValue)
                                        .foregroundColor(.primary)
                                    Spacer()
                                }
                                .font(.title3)
                                .frame(height: 52, alignment: .center)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            if preset != TitlePreset.allCases.last {
                                Divider()
                            }
                        }
                    }
                }

                // Date & time input
                Section(header: Text("Date & Time")) {
                    HStack {
                        DatePicker("", selection: $date, displayedComponents: [.date, .hourAndMinute])
                            .labelsHidden()
                        Spacer(minLength: 0)
                    }
                }

                // Recurring options
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

                    if selectedPreset == .payday && !repeatsMonthly && !repeatsWeekly {
                        Text("Pay Day must repeat monthly or weekly.")
                            .font(.footnote)
                            .foregroundColor(.red)
                    }
                }

                // Card style selection
                Section(header: Text("Card Style")) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(Array(AppGradients.customEvent.enumerated()), id: \.offset) { idx, grad in
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(grad)
                                        .frame(width: 64, height: 44)
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
                                .onTapGesture { styleIndex = idx }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Add Countdown")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        // Determine anchor date for recurrence (weekly may adjust the weekday).
                        let calendar = Calendar.singapore
                        var anchorDate = date

                        if repeatsWeekly {
                            let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: date)
                            var components = calendar.dateComponents([.year, .month, .day], from: date)
                            components.weekday = weeklyDayOfWeek
                            components.hour = timeComponents.hour
                            components.minute = timeComponents.minute
                            components.second = timeComponents.second
                            // Find the next matching weekday on or after the chosen date.
                            if let next = calendar.nextDate(
                                after: date.addingTimeInterval(-60),
                                matching: components,
                                matchingPolicy: .nextTimePreservingSmallerComponents
                            ) {
                                anchorDate = next
                            }
                        }

                        let event = CustomEvent(
                            title: trimmed,
                            date: anchorDate,
                            styleIndex: styleIndex,
                            repeatsMonthly: repeatsMonthly,
                            monthlyDay: repeatsMonthly ? monthlyDay : nil,
                            repeatsWeekly: repeatsWeekly,
                            weeklyInterval: repeatsWeekly ? weeklyInterval : nil
                        )
                        onSave(event)
                        dismiss()
                    }
                    .disabled(
                        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                        (selectedPreset == .payday && !repeatsMonthly && !repeatsWeekly)
                    )
                }
            }
            .onAppear {
                // No default selection; ensure empty title initially
                if selectedPreset == nil { title = "" }
            }
            .onChange(of: selectedPreset) { _, newValue in
                title = newValue?.rawValue ?? ""
                // For Pay Day preset, default to monthly recurrence.
                if newValue == .payday {
                    if !repeatsMonthly && !repeatsWeekly {
                        repeatsMonthly = true
                        let calendar = Calendar.singapore
                        monthlyDay = calendar.component(.day, from: date)
                    }
                }
            }
        }
    }
}
