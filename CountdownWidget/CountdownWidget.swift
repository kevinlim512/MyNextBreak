import WidgetKit
import SwiftUI

struct CountdownWidgetEntry: TimelineEntry {
    let date: Date
    let id: UUID?
    let title: String
    let subtitle: String?
    let targetDate: Date
}

struct CountdownWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> CountdownWidgetEntry {
        CountdownWidgetEntry(
            date: Date(),
            id: WidgetCountdownConfig.nextTimeOffID,
            title: "My Next Break",
            subtitle: nil,
            targetDate: Date().addingTimeInterval(60 * 60 * 24)
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (CountdownWidgetEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CountdownWidgetEntry>) -> Void) {
        let entry = loadEntry()
        let nextUpdate = Calendar.current.date(
            byAdding: .minute,
            value: 15,
            to: Date()
        ) ?? Date().addingTimeInterval(60 * 15)
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func loadEntry() -> CountdownWidgetEntry {
        if let config = WidgetCountdownConfig.load() {
            var target = config.nextTargetDate(from: Date())
            var subtitle = config.subtitle

            // For the built-in holiday modes, prefer the shared "current" holiday snapshot
            // so the widget stays consistent with what the app is showing.
            if config.id == WidgetCountdownConfig.nextPublicHolidayID,
               let info = WidgetHolidayInfo.loadNextPublicHoliday() {
                target = info.date
                subtitle = info.name
            } else if config.id == WidgetCountdownConfig.nextLongWeekendID,
                      let info = WidgetHolidayInfo.loadNextLongWeekend() {
                target = info.date
                subtitle = info.name
            }

            return CountdownWidgetEntry(
                date: Date(),
                id: config.id,
                title: config.title,
                subtitle: subtitle,
                targetDate: target
            )
        } else {
            return CountdownWidgetEntry(
                date: Date(),
                id: nil,
                title: "Pick a countdown",
                subtitle: nil,
                targetDate: Date()
            )
        }
    }
}

struct CountdownWidgetEntryView: View {
    var entry: CountdownWidgetEntry

    var body: some View {
        GeometryReader { geo in
            let isCompact = geo.size.width < 200
            let titleScale = isCompact ? 0.12 : 0.14
            let subtitleScale = isCompact ? 0.105 : 0.12
            let timeScale = isCompact
                ? ((entry.subtitle?.isEmpty ?? true) ? 0.52 : 0.46)
                : ((entry.subtitle?.isEmpty ?? true) ? 0.6 : 0.52)

            VStack(alignment: .leading, spacing: 8) {
                Text(entry.title)
                    .font(.system(size: geo.size.height * titleScale, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)

                if let subtitle = entry.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: geo.size.height * subtitleScale, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.95))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                Spacer(minLength: 0)

                Text(timeRemaining(to: entry.targetDate))
                    .font(.system(size: geo.size.height * timeScale, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.3)
                    .lineLimit(1)
            }
            .padding(12)
            .frame(width: geo.size.width, height: geo.size.height, alignment: .leading)
            .containerBackground(for: .widget) {
                widgetBackground(for: entry.id)
            }
        }
    }

    private func widgetBackground(for id: UUID?) -> LinearGradient {
        switch id {
        case WidgetCountdownConfig.nextPublicHolidayID:
            LinearGradient(
                gradient: Gradient(colors: [Color.orange, Color.red]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case WidgetCountdownConfig.nextLongWeekendID:
            LinearGradient(
                gradient: Gradient(colors: [Color.green, Color.teal]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        default:
            LinearGradient(
                gradient: Gradient(colors: [Color.purple, Color.blue]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private func timeRemaining(to date: Date) -> String {
        let diff = Int(date.timeIntervalSinceNow)
        if diff <= 0 {
            return "Now!"
        }

        let days = diff / 86_400
        let hours = (diff % 86_400) / 3_600
        let minutes = (diff % 3_600) / 60

        return "\(days)d \(hours)h \(minutes)m"
    }
}

@main
struct CountdownWidget: Widget {
    let kind: String = "CountdownWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CountdownWidgetProvider()) { entry in
            CountdownWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("My Next Break")
        .description("Shows the countdown you picked in the app.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
