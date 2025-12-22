import SwiftUI

/// View that lets the user pick which custom countdown is shown in the home screen widget.
/// Presents a vertical list of created countdowns showing only their titles.
struct EditWidgetView: View {
    @EnvironmentObject var model: CountdownModel
    @ObservedObject private var customStore = CustomEventStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedConfig: WidgetCountdownConfig?

    var body: some View {
        List {
            // Default smart countdown options backed by the main model
            Section(header: Text("Default Countdowns")) {
                Button {
                    let config = WidgetCountdownConfig(
                        id: WidgetCountdownConfig.nextTimeOffID,
                        title: "Next Time Off",
                        date: model.nextNonWorkingDate
                    )
                    WidgetCountdownConfig.save(config)
                    selectedConfig = config
                    dismiss()
                } label: {
                    HStack {
                        Text("Next Time Off")
                            .foregroundColor(.primary)
                        Spacer()
                        if selectedConfig?.id == WidgetCountdownConfig.nextTimeOffID {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                }

                Button {
                    guard let nextHoliday = model.nextHoliday else { return }
                    _ = WidgetHolidayInfo.storeNextPublicHoliday(WidgetHolidayInfo(name: nextHoliday.name, date: nextHoliday.date))
                    let config = WidgetCountdownConfig(
                        id: WidgetCountdownConfig.nextPublicHolidayID,
                        title: "Next Public Holiday",
                        date: nextHoliday.date,
                        subtitle: nextHoliday.name
                    )
                    WidgetCountdownConfig.save(config)
                    selectedConfig = config
                    dismiss()
                } label: {
                    HStack {
                        Text("Next Public Holiday")
                            .foregroundColor(model.nextHoliday == nil ? .secondary : .primary)
                        Spacer()
                        if selectedConfig?.id == WidgetCountdownConfig.nextPublicHolidayID {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                }
                .disabled(model.nextHoliday == nil)

                Button {
                    guard let longWeekend = model.nextLongWeekendHoliday else { return }
                    _ = WidgetHolidayInfo.storeNextLongWeekend(WidgetHolidayInfo(name: longWeekend.name, date: longWeekend.date))
                    let config = WidgetCountdownConfig(
                        id: WidgetCountdownConfig.nextLongWeekendID,
                        title: "Next Long Weekend",
                        date: longWeekend.date,
                        subtitle: longWeekend.name
                    )
                    WidgetCountdownConfig.save(config)
                    selectedConfig = config
                    dismiss()
                } label: {
                    HStack {
                        Text("Next Long Weekend")
                            .foregroundColor(model.nextLongWeekendHoliday == nil ? .secondary : .primary)
                        Spacer()
                        if selectedConfig?.id == WidgetCountdownConfig.nextLongWeekendID {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                }
                .disabled(model.nextLongWeekendHoliday == nil)
            }

            // Custom user-created countdowns
            Section(header: Text("Custom Countdowns")) {
                if customStore.events.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("No Custom Countdowns")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("Create a countdown in the main app, then you can choose it here.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                } else {
                    ForEach(customStore.events) { event in
                        Button(action: {
                            WidgetCountdownConfig.save(from: event)
                            selectedConfig = WidgetCountdownConfig(id: event.id, title: event.title, date: event.date)
                            dismiss()
                        }) {
                            HStack {
                                Text(event.title)
                                    .foregroundColor(.primary)
                                Spacer()
                                if selectedConfig?.id == event.id {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Edit Widget")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .onAppear {
            selectedConfig = WidgetCountdownConfig.load()
        }
    }
}
