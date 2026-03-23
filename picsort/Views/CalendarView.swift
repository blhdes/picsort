import SwiftUI

/// Pure SwiftUI calendar grid — no UIDatePicker, no rogue animations.
struct CalendarView: View {
    @Binding var selectedDate: Date
    var earliest: Date = .distantPast
    var latest: Date = .distantFuture

    @State private var displayedMonth = Date()

    private let calendar = Calendar.current
    private let weekdaySymbols = Calendar.current.shortStandaloneWeekdaySymbols
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    var body: some View {
        VStack(spacing: 16) {
            // Month header
            HStack {
                Text(monthYearLabel)
                    .font(.body)
                    .fontWeight(.semibold)

                Spacer()

                Button { changeMonth(by: -1) } label: {
                    Image(systemName: "chevron.left")
                }
                .disabled(!canGoBack)

                Button { changeMonth(by: 1) } label: {
                    Image(systemName: "chevron.right")
                }
                .disabled(!canGoForward)
            }

            // Weekday headers (Mon first)
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(orderedWeekdaySymbols, id: \.self) { symbol in
                    Text(symbol.uppercased())
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Day grid — always 6 rows so height never changes
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(daysInGrid, id: \.self) { day in
                    dayCell(day)
                }
            }
        }
        .onAppear {
            displayedMonth = calendar.startOfMonth(for: selectedDate)
        }
    }

    // MARK: - Day Cell

    @ViewBuilder
    private func dayCell(_ day: Date?) -> some View {
        if let day {
            let isSelected = calendar.isDate(day, inSameDayAs: selectedDate)
            let isToday = calendar.isDateInToday(day)
            let isEnabled = day >= calendar.startOfDay(for: earliest)
                         && day <= calendar.startOfDay(for: latest)

            Button {
                selectedDate = day
            } label: {
                Text("\(calendar.component(.day, from: day))")
                    .font(.body)
                    .fontWeight(isToday ? .bold : .regular)
                    .foregroundStyle(
                        !isEnabled ? Color.gray.opacity(0.3) :
                        isSelected ? Color.white :
                        isToday ? Color.accentColor :
                        Color.primary
                    )
                    .frame(maxWidth: .infinity, minHeight: 36)
                    .background {
                        if isSelected {
                            Circle().fill(Color.accentColor)
                        } else if isToday {
                            Circle().strokeBorder(Color.accentColor, lineWidth: 1)
                        }
                    }
            }
            .disabled(!isEnabled)
        } else {
            Color.clear.frame(minHeight: 36)
        }
    }

    // MARK: - Grid Data

    /// Returns exactly 42 slots (6 rows x 7 columns). Empty slots are nil.
    private var daysInGrid: [Date?] {
        let first = calendar.startOfMonth(for: displayedMonth)
        let range = calendar.range(of: .day, in: .month, for: first)!

        // Weekday of the 1st, shifted so Monday = 0
        let rawWeekday = calendar.component(.weekday, from: first)
        let offset = (rawWeekday + 5) % 7 // Mon=0, Tue=1, ..., Sun=6

        var grid: [Date?] = Array(repeating: nil, count: 42)

        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: first) {
                grid[offset + day - 1] = date
            }
        }

        return grid
    }

    /// Weekday symbols starting from Monday.
    private var orderedWeekdaySymbols: [String] {
        let symbols = weekdaySymbols
        // Calendar weekday indices: 1=Sun, 2=Mon … 7=Sat
        // Reorder to Mon…Sun
        return Array(symbols[1...]) + [symbols[0]]
    }

    // MARK: - Month Navigation

    private var monthYearLabel: String {
        displayedMonth.formatted(.dateTime.month(.wide).year())
    }

    private var canGoBack: Bool {
        guard let prevMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) else { return false }
        let endOfPrev = calendar.endOfMonth(for: prevMonth)
        return endOfPrev >= calendar.startOfDay(for: earliest)
    }

    private var canGoForward: Bool {
        guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) else { return false }
        let startOfNext = calendar.startOfMonth(for: nextMonth)
        return startOfNext <= calendar.startOfDay(for: latest)
    }

    private func changeMonth(by value: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) {
            displayedMonth = newMonth
        }
    }
}

// MARK: - Calendar Helpers

private extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components)!
    }

    func endOfMonth(for date: Date) -> Date {
        let start = startOfMonth(for: date)
        return self.date(byAdding: DateComponents(month: 1, day: -1), to: start)!
    }
}
