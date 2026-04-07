import Foundation

enum ReminderState {
    case disabled
    case snoozed(until: Date)
    case waiting(next: Date)
}

final class ReminderScheduler {
    private(set) var settings: AppSettings
    private(set) var nextReminderDate: Date?
    private(set) var snoozedUntil: Date?

    private let calendar = Calendar.current

    init(settings: AppSettings) {
        self.settings = settings
        recalculate(from: Date())
    }

    func updateSettings(_ settings: AppSettings, now: Date = Date()) {
        self.settings = settings
        recalculate(from: now)
    }

    func setEnabled(_ isEnabled: Bool, now: Date = Date()) {
        settings.isEnabled = isEnabled
        recalculate(from: now)
    }

    func snooze(now: Date = Date()) {
        let snoozeDate = now.addingTimeInterval(TimeInterval(settings.snoozeMinutes * 60))
        snoozedUntil = nextActiveMoment(onOrAfter: snoozeDate)
        nextReminderDate = snoozedUntil
    }

    func skipSnooze(now: Date = Date()) {
        snoozedUntil = nil
        nextReminderDate = nextIntervalReminder(from: now)
    }

    func check(now: Date = Date()) -> Bool {
        guard settings.isEnabled else {
            nextReminderDate = nil
            return false
        }

        if let snoozedUntil, now < snoozedUntil {
            nextReminderDate = snoozedUntil
            return false
        }

        if let snoozedUntil, now >= snoozedUntil {
            self.snoozedUntil = nil
            nextReminderDate = now
        }

        if nextReminderDate == nil {
            nextReminderDate = nextIntervalReminder(from: now)
            return false
        }

        guard let nextReminderDate, now >= nextReminderDate else {
            return false
        }

        self.nextReminderDate = nextIntervalReminder(from: now)
        return true
    }

    func remindNow(now: Date = Date()) {
        snoozedUntil = nil
        nextReminderDate = nextIntervalReminder(from: now)
    }

    func status(now: Date = Date()) -> ReminderState {
        guard settings.isEnabled else {
            return .disabled
        }

        if let snoozedUntil, now < snoozedUntil {
            return .snoozed(until: snoozedUntil)
        }

        if let nextReminderDate {
            return .waiting(next: nextReminderDate)
        }

        return .waiting(next: nextIntervalReminder(from: now))
    }

    func formattedActiveWindow() -> String {
        "\(formattedHour(settings.activeStartHour)) to \(formattedHour(settings.activeEndHour))"
    }

    private func recalculate(from now: Date) {
        guard settings.isEnabled else {
            snoozedUntil = nil
            nextReminderDate = nil
            return
        }

        if let snoozedUntil, now < snoozedUntil {
            nextReminderDate = snoozedUntil
            return
        }

        snoozedUntil = nil
        nextReminderDate = nextIntervalReminder(from: now)
    }

    private func nextIntervalReminder(from reference: Date) -> Date {
        let interval = TimeInterval(settings.intervalMinutes * 60)

        if isWithinActiveWindow(reference) {
            let candidate = reference.addingTimeInterval(interval)
            if isWithinActiveWindow(candidate) {
                return candidate
            }

            let nextStart = nextActiveStart(after: candidate)
            return nextStart.addingTimeInterval(interval)
        }

        let nextStart = nextActiveStart(after: reference)
        return nextStart.addingTimeInterval(interval)
    }

    private func nextActiveMoment(onOrAfter date: Date) -> Date {
        if isWithinActiveWindow(date) {
            return date
        }

        return nextActiveStart(after: date)
    }

    private func isWithinActiveWindow(_ date: Date) -> Bool {
        let hour = calendar.component(.hour, from: date)
        return hour >= settings.activeStartHour && hour < settings.activeEndHour
    }

    private func nextActiveStart(after date: Date) -> Date {
        let startToday = dayHour(date, hour: settings.activeStartHour)

        if date < startToday {
            return startToday
        }

        return calendar.date(byAdding: .day, value: 1, to: startToday) ?? startToday
    }

    private func dayHour(_ date: Date, hour: Int) -> Date {
        let startOfDay = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .hour, value: hour, to: startOfDay) ?? startOfDay
    }

    private func formattedHour(_ hour: Int) -> String {
        let startOfDay = calendar.startOfDay(for: Date())
        let date = calendar.date(byAdding: .hour, value: hour, to: startOfDay) ?? startOfDay
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
}
