import SwiftUI

/// Settings view for configuring working days and managing holiday data
/// Allows users to customize their work schedule and refresh holiday information
struct SettingsView: View {
    // MARK: - Properties
    @AppStorage("workingDaysArray") private var workingDaysArray: String = "true,true,true,true,true,false,false"
    @AppStorage("hasCompletedSetup") private var hasCompletedSetup: Bool = false
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var model: CountdownModel
    @StateObject private var holidayStore = HolidayStore()
    // Notify caller that working days were saved/changed
    var onSaveWorkingDays: (() -> Void)? = nil

    // Working days configuration (Monday-Sunday, true=working, false=off)
    // Default: Mon–Fri ON, Sat/Sun OFF (customizable by user)
    @State private var selectedDays: [Bool] = [true, true, true, true, true, false, false]

    let fullDayNames = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

    var body: some View {
        NavigationView {
            Form {
                // Working Days Configuration Section
                Section(header: Text("Working Days")) {
                    VStack(alignment: .leading, spacing: 16) {
                        // Toggle for each day of the week
                        ForEach(selectedDays.indices, id: \.self) { i in
                            Toggle(isOn: $selectedDays[i]) {
                                Text(fullDayNames[i])
                                    .font(.title2)
                                    .fontWeight(.medium)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // Holiday Database Management Section
                Section(header: Text("Holiday Database")) {
                    VStack(alignment: .leading, spacing: 12) {
                        // Download status indicator
                        HStack {
                            Image(systemName: "calendar.badge.clock")
                                .foregroundColor(.blue)
                            Text("Status:")
                                .fontWeight(.medium)
                            Spacer()
                            statusText
                        }
                        
                        // Show detailed download information if available
                        if case .downloaded(let date, let years) = holidayStore.downloadStatus {
                            VStack(alignment: .leading, spacing: 4) {
                                // Available years
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("Years: \(years.joined(separator: ", "))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                // Last update timestamp
                                HStack {
                                    Image(systemName: "clock")
                                        .foregroundColor(.gray)
                                    Text("Last updated: \(DateFormatter.shortDateTime.string(from: date))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        // Refresh button for holiday data
                        Button(action: {
                            Task {
                                await holidayStore.refreshHolidayData()
                            }
                        }) {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text("Refresh Holiday Data")
                            }
                            .foregroundColor(.blue)
                        }
                        .disabled(holidayStore.downloadStatus == .downloading)
                    }
                    .padding(.vertical, 8)
                }

                // Setup Flow Section
                Section(header: Text("Setup")) {
                    Button(role: .none) {
                        // Trigger setup flow again by clearing the completion flag
                        hasCompletedSetup = false
                        // Close settings; ContentView will present SetupView
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.counterclockwise.circle")
                            Text("Redo Initial Setup")
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        // Compute new configuration string
                        let newValue = selectedDays.map { $0 ? "true" : "false" }.joined(separator: ",")
                        // Only save and notify if it changed
                        if newValue != workingDaysArray {
                            workingDaysArray = newValue
                            onSaveWorkingDays?()
                        }
                        // Close settings either way
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.title2)
                    }
                }
            }
            .onAppear {
                // Load working days configuration from AppStorage
                let parts = workingDaysArray.split(separator: ",").map { $0 == "true" }
                if parts.count == 7 {
                    selectedDays = parts
                }
            }
        }
    }
    
    /// Status text view builder that displays the current holiday download status
    @ViewBuilder
    private var statusText: some View {
        switch holidayStore.downloadStatus {
        case .notDownloaded:
            Text("Not Downloaded")
                .foregroundColor(.orange)
                .fontWeight(.medium)
        case .downloading:
            HStack {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Downloading...")
                    .foregroundColor(.blue)
                    .fontWeight(.medium)
            }
        case .downloaded:
            Text("Downloaded")
                .foregroundColor(.green)
                .fontWeight(.medium)
        case .error(_):
            Text("Error")
                .foregroundColor(.red)
                .fontWeight(.medium)
        }
    }
}

/// DateFormatter extension for consistent date/time formatting
extension DateFormatter {
    static let shortDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
}
