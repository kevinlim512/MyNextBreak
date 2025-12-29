import SwiftUI

struct WeeklyDatePickerView: View {
    @Binding var date: Date
    let weekday: Int?

    @Environment(\.dismiss) private var dismiss
    @State private var displayedMonth: Date

    init(date: Binding<Date>, weekday: Int? = nil) {
        _date = date
        self.weekday = weekday
        let calendar = Calendar.singapore
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: date.wrappedValue))
            ?? date.wrappedValue
        _displayedMonth = State(initialValue: startOfMonth)
    }

    var body: some View {
        VStack(spacing: 16) {
            header
            weekdayHeader
            calendarGrid
            Spacer()
        }
        .padding(.horizontal)
        .navigationTitle("Select Date")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        HStack {
            Text(displayedMonth, format: .dateTime.year().month(.wide))
                .font(.headline)
            Spacer()
            Button {
                displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 6)

            Button {
                displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3)
            }
            .buttonStyle(.plain)
        }
        .padding(.trailing, 12)
    }

    private var weekdayHeader: some View {
        let symbols = orderedWeekdaySymbols
        return HStack {
            ForEach(symbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var calendarGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)
        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(dayCells) { cell in
                if let date = cell.date {
                    Button {
                        guard cell.isSelectable else { return }
                        selectDate(date)
                    } label: {
                        Text("\(cell.day)")
                            .font(.body)
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(cell.isSelected ? Color.blue.opacity(0.2) : Color.clear)
                            )
                            .foregroundColor(cell.isSelected ? .blue : (cell.isSelectable ? .primary : .secondary))
                    }
                    .buttonStyle(.plain)
                    .disabled(!cell.isSelectable)
                    .frame(maxWidth: .infinity)
                } else {
                    Color.clear
                        .frame(height: 36)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var calendar: Calendar { Calendar.singapore }

    private var orderedWeekdaySymbols: [String] {
        let symbols = calendar.shortWeekdaySymbols.map { $0.uppercased() }
        let startIndex = max(calendar.firstWeekday - 1, 0)
        return Array(symbols[startIndex...] + symbols[..<startIndex])
    }

    private var dayCells: [DayCell] {
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth))
            ?? displayedMonth
        guard let range = calendar.range(of: .day, in: .month, for: startOfMonth) else {
            return []
        }
        let firstWeekday = calendar.component(.weekday, from: startOfMonth)
        let leadingBlanks = (firstWeekday - calendar.firstWeekday + 7) % 7

        var cells: [DayCell] = Array(repeating: DayCell.empty, count: leadingBlanks)
        for day in range {
            let dayDate = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth) ?? startOfMonth
            let isSelectable: Bool
            if let weekday = weekday {
                isSelectable = calendar.component(.weekday, from: dayDate) == weekday
            } else {
                isSelectable = true
            }
            let isSelected = calendar.isDate(dayDate, inSameDayAs: date)
            cells.append(DayCell(date: dayDate, day: day, isSelectable: isSelectable, isSelected: isSelected))
        }
        return cells
    }

    private func selectDate(_ selectedDate: Date) {
        let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: date)
        var components = calendar.dateComponents([.year, .month, .day], from: selectedDate)
        components.hour = timeComponents.hour
        components.minute = timeComponents.minute
        components.second = timeComponents.second
        date = calendar.date(from: components) ?? selectedDate
        dismiss()
    }

    private struct DayCell: Identifiable {
        let id = UUID()
        let date: Date?
        let day: Int
        let isSelectable: Bool
        let isSelected: Bool

        static let empty = DayCell(date: nil, day: 0, isSelectable: false, isSelected: false)
    }
}
