import SwiftUI

/// Initial setup screen for configuring working days
/// Shown on first launch and can be re-run from Settings
struct SetupView: View {
    @AppStorage("workingDaysArray") private var workingDaysArray: String = "true,true,true,true,true,false,false"
    @AppStorage("hasCompletedSetup") private var hasCompletedSetup: Bool = false

    @State private var selectedDays: [Bool] = [true, true, true, true, true, false, false]

    private let fullDayNames = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                formContent
                footerButtons
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .interactiveDismissDisabled(true)
        .onAppear(perform: loadExisting)
        .onChange(of: preset) { _, newValue in
            // Keep the visible picker in sync; skip .custom which isn't shown
            if newValue != .custom {
                pickerSelection = newValue
            }
        }
        .onChange(of: pickerSelection) { _, newValue in
            // Apply the visible preset selection and reflect it in preset
            preset = newValue
            applyPreset(newValue)
        }
        .onChange(of: selectedDays) { _, _ in
            preset = inferPreset(from: selectedDays)
        }
    }

    // MARK: - Subviews
    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Welcome 👋")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Set your working days so we can tailor the Leave Planning feature to your schedule.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 32)
        .padding(.bottom, 16)
    }

    private var formContent: some View {
        Form {
            Section(header: workingDaysHeader) {
                workingDaysToggles
            }

            Section(header: presetHeader, footer: Text("You can change this any time from Settings.")) {
                presetPicker
            }
        }
    }

    private var workingDaysHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "briefcase")
                .foregroundColor(.blue)
            Text("Your Working Days")
                .font(.subheadline)
                .fontWeight(.semibold)
                .textCase(nil)
        }
        .padding(.top, 12)
    }

    private var workingDaysToggles: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(0..<7, id: \.self) { i in
                Toggle(isOn: bindingForDay(index: i)) {
                    Text(fullDayNames[i])
                        .font(.title3)
                        .fontWeight(.medium)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func bindingForDay(index: Int) -> Binding<Bool> {
        Binding<Bool>(
            get: { index < selectedDays.count ? selectedDays[index] : false },
            set: { newValue in
                if index < selectedDays.count { selectedDays[index] = newValue }
            }
        )
    }

    private var presetHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "slider.horizontal.3")
                .foregroundColor(.orange)
            Text("Quick Preset")
                .font(.subheadline)
                .fontWeight(.semibold)
                .textCase(nil)
        }
        .padding(.vertical, 6)
    }

    private var presetPicker: some View {
        Picker("", selection: $pickerSelection) {
            HStack {
                Image(systemName: "briefcase")
                Text("Weekdays")
            }.tag(Preset.weekdays)
            HStack {
                Image(systemName: "calendar")
                Text("All Days")
            }.tag(Preset.allDays)
            HStack {
                Image(systemName: "moon")
                Text("No Days")
            }.tag(Preset.noDays)
        }
        .labelsHidden()
        .pickerStyle(.inline)
    }

    private var footerButtons: some View {
        VStack {
            Button(action: completeSetup) {
                Text("Continue")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
    }

    enum Preset: Hashable {
        case weekdays
        case allDays
        case noDays
        case custom
    }

    @State private var preset: Preset = .weekdays
    @State private var pickerSelection: Preset = .weekdays

    private func loadExisting() {
        let parts = workingDaysArray.split(separator: ",").map { $0 == "true" }
        if parts.count == 7 {
            selectedDays = parts
        }
        preset = inferPreset(from: selectedDays)
        // Initialize the visible picker selection; default to weekdays when custom
        pickerSelection = (preset == .custom) ? .weekdays : preset
    }

    private func completeSetup() {
        workingDaysArray = selectedDays.map { $0 ? "true" : "false" }.joined(separator: ",")
        hasCompletedSetup = true
    }

    private func applyPreset(_ preset: Preset) {
        switch preset {
        case .weekdays:
            selectedDays = [true, true, true, true, true, false, false]
        case .allDays:
            selectedDays = Array(repeating: true, count: 7)
        case .noDays:
            selectedDays = Array(repeating: false, count: 7)
        case .custom:
            break
        }
    }

    private func inferPreset(from days: [Bool]) -> Preset {
        if days == [true, true, true, true, true, false, false] { return .weekdays }
        if days == Array(repeating: true, count: 7) { return .allDays }
        if days == Array(repeating: false, count: 7) { return .noDays }
        return .custom
    }
}
