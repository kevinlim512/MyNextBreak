import Foundation
import AppIntents

/// Entity representing a single countdown that can be picked in the widget configuration UI.
@available(iOS 17.0, *)
struct CountdownAppEntity: AppEntity, Identifiable, Hashable {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "Countdown"
    }
    static var defaultQuery = CountdownAppEntityQuery()

    let id: UUID
    let title: String
    let date: Date

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)")
    }
}

/// Query that provides the list of available countdowns for the widget configuration.
/// These are mirrored from the main app into the shared app group.
@available(iOS 17.0, *)
struct CountdownAppEntityQuery: EntityQuery {
    func entities(for identifiers: [CountdownAppEntity.ID]) async throws -> [CountdownAppEntity] {
        let all = try await suggestedEntities()
        return all.filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [CountdownAppEntity] {
        let configs = WidgetCountdownConfig.loadAll()
        return configs.map { CountdownAppEntity(id: $0.id, title: $0.title, date: $0.date) }
    }
}

/// AppIntent used by the widget configuration. When the user long-presses the widget and taps
/// "Edit Widget", iOS shows a list of these countdowns to choose from.
@available(iOS 17.0, *)
struct CountdownSelectionIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select Countdown"
    static var description = IntentDescription("Choose which countdown to show in the widget.")

    @available(iOS 17.0, *)
    @Parameter(title: "Countdown")
    var countdown: CountdownAppEntity?

    init() {}
}
