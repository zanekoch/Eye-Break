import Foundation

struct AppSettings {
    static let defaultIntervalMinutes = 20
    static let defaultSnoozeMinutes = 75
    static let defaultStartHour = 8
    static let defaultEndHour = 20

    var intervalMinutes: Int
    var snoozeMinutes: Int
    var activeStartHour: Int
    var activeEndHour: Int
    var isEnabled: Bool

    init(
        intervalMinutes: Int = AppSettings.defaultIntervalMinutes,
        snoozeMinutes: Int = AppSettings.defaultSnoozeMinutes,
        activeStartHour: Int = AppSettings.defaultStartHour,
        activeEndHour: Int = AppSettings.defaultEndHour,
        isEnabled: Bool = true
    ) {
        self.intervalMinutes = intervalMinutes
        self.snoozeMinutes = snoozeMinutes
        self.activeStartHour = activeStartHour
        self.activeEndHour = activeEndHour
        self.isEnabled = isEnabled
        normalize()
    }

    mutating func normalize() {
        intervalMinutes = max(1, min(intervalMinutes, 240))
        snoozeMinutes = max(1, min(snoozeMinutes, 480))
        activeStartHour = max(0, min(activeStartHour, 23))
        activeEndHour = max(1, min(activeEndHour, 24))

        if activeStartHour >= activeEndHour {
            activeStartHour = AppSettings.defaultStartHour
            activeEndHour = AppSettings.defaultEndHour
        }
    }
}

enum DefaultsKey {
    static let intervalMinutes = "intervalMinutes"
    static let snoozeMinutes = "snoozeMinutes"
    static let activeStartHour = "activeStartHour"
    static let activeEndHour = "activeEndHour"
    static let isEnabled = "isEnabled"
}

enum SettingsStore {
    static func load() -> AppSettings {
        let defaults = UserDefaults.standard
        let hasStoredSettings = defaults.object(forKey: DefaultsKey.intervalMinutes) != nil

        guard hasStoredSettings else {
            return AppSettings()
        }

        var settings = AppSettings(
            intervalMinutes: defaults.integer(forKey: DefaultsKey.intervalMinutes),
            snoozeMinutes: defaults.integer(forKey: DefaultsKey.snoozeMinutes),
            activeStartHour: defaults.integer(forKey: DefaultsKey.activeStartHour),
            activeEndHour: defaults.integer(forKey: DefaultsKey.activeEndHour),
            isEnabled: defaults.object(forKey: DefaultsKey.isEnabled) as? Bool ?? true
        )
        settings.normalize()
        return settings
    }

    static func save(_ settings: AppSettings) {
        let defaults = UserDefaults.standard
        defaults.set(settings.intervalMinutes, forKey: DefaultsKey.intervalMinutes)
        defaults.set(settings.snoozeMinutes, forKey: DefaultsKey.snoozeMinutes)
        defaults.set(settings.activeStartHour, forKey: DefaultsKey.activeStartHour)
        defaults.set(settings.activeEndHour, forKey: DefaultsKey.activeEndHour)
        defaults.set(settings.isEnabled, forKey: DefaultsKey.isEnabled)
    }
}
