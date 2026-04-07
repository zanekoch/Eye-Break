import AppKit
import ServiceManagement
@preconcurrency import UserNotifications

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, @preconcurrency UNUserNotificationCenterDelegate {
    private enum Constants {
        static let heartbeatSeconds: TimeInterval = 10
        static let intervalPresets = [10, 15, 20, 30, 45, 60]
        static let snoozePresets = [15, 30, 45, 60, 75, 90]
    }

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()
    private let scheduler = ReminderScheduler(settings: SettingsStore.load())
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    private var heartbeatTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        applyAppIcon()
        UNUserNotificationCenter.current().delegate = self
        requestNotificationPermission()
        configureStatusItem()
        rebuildMenu()
        startHeartbeat()
    }

    func applicationWillTerminate(_ notification: Notification) {
        heartbeatTimer?.invalidate()
    }

    func menuWillOpen(_ menu: NSMenu) {
        rebuildMenu()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list])
    }

    @objc
    private func toggleEnabled(_ sender: NSMenuItem) {
        var settings = scheduler.settings
        settings.isEnabled.toggle()
        SettingsStore.save(settings)
        scheduler.updateSettings(settings)
        refreshStatusItem()
        rebuildMenu()
    }

    @objc
    private func snoozeReminder(_ sender: NSMenuItem) {
        scheduler.snooze()
        refreshStatusItem()
        rebuildMenu()
    }

    @objc
    private func remindNow(_ sender: NSMenuItem) {
        deliverReminder()
    }

    @objc
    private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        let service = SMAppService.mainApp

        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {
            showAlert(
                title: "Launch at Login",
                message: "EyeBreak could not update the login-item setting.\n\n\(error.localizedDescription)"
            )
        }

        rebuildMenu()
    }

    @objc
    private func updateInterval(_ sender: NSMenuItem) {
        let minutes = sender.tag
        applyInterval(minutes)
    }

    @objc
    private func customInterval(_ sender: NSMenuItem) {
        guard let value = promptForMinutes(
            title: "Custom Reminder Interval",
            message: "Set how many minutes should pass between eye-break reminders.",
            initialValue: scheduler.settings.intervalMinutes
        ) else {
            return
        }

        applyInterval(value)
    }

    @objc
    private func updateSnoozeLength(_ sender: NSMenuItem) {
        let minutes = sender.tag
        applySnoozeLength(minutes)
    }

    @objc
    private func customSnoozeLength(_ sender: NSMenuItem) {
        guard let value = promptForMinutes(
            title: "Default Snooze Length",
            message: "Set the default snooze length in minutes.",
            initialValue: scheduler.settings.snoozeMinutes
        ) else {
            return
        }

        applySnoozeLength(value)
    }

    @objc
    private func configureActiveHours(_ sender: NSMenuItem) {
        let settings = scheduler.settings
        guard let hours = promptForActiveHours(
            startHour: settings.activeStartHour,
            endHour: settings.activeEndHour
        ) else {
            return
        }

        var updated = settings
        updated.activeStartHour = hours.start
        updated.activeEndHour = hours.end
        updated.normalize()
        SettingsStore.save(updated)
        scheduler.updateSettings(updated)
        refreshStatusItem()
        rebuildMenu()
    }

    @objc
    private func quitApp(_ sender: NSMenuItem) {
        NSApplication.shared.terminate(nil)
    }

    private func configureStatusItem() {
        statusItem.menu = menu
        menu.delegate = self

        if let button = statusItem.button {
            button.imagePosition = .imageOnly
        }

        refreshStatusItem()
    }

    private func startHeartbeat() {
        heartbeatTimer = Timer.scheduledTimer(
            timeInterval: Constants.heartbeatSeconds,
            target: self,
            selector: #selector(onHeartbeat),
            userInfo: nil,
            repeats: true
        )
        RunLoop.main.add(heartbeatTimer!, forMode: .common)
    }

    @objc
    private func onHeartbeat() {
        if scheduler.check() {
            deliverReminder()
        }

        refreshStatusItem()
    }

    private func applyInterval(_ minutes: Int) {
        var settings = scheduler.settings
        settings.intervalMinutes = minutes
        settings.normalize()
        SettingsStore.save(settings)
        scheduler.updateSettings(settings)
        refreshStatusItem()
        rebuildMenu()
    }

    private func applySnoozeLength(_ minutes: Int) {
        var settings = scheduler.settings
        settings.snoozeMinutes = minutes
        settings.normalize()
        SettingsStore.save(settings)
        scheduler.updateSettings(settings)
        refreshStatusItem()
        rebuildMenu()
    }

    private func deliverReminder() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { [weak self] settings in
            guard let self else {
                return
            }

            let isAuthorized = settings.authorizationStatus == .authorized
                || settings.authorizationStatus == .provisional

            guard isAuthorized else {
                Task { @MainActor in
                    self.showNotificationPermissionWarning()
                }
                return
            }

            let content = UNMutableNotificationContent()
            content.title = "Eye break"
            content.body = "Look away from your screen for a moment and rest your eyes."
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: "EyeBreakReminder.\(UUID().uuidString)",
                content: content,
                trigger: nil
            )

            center.add(request) { error in
                Task { @MainActor in
                    if let error {
                        self.showAlert(
                            title: "Notification Failed",
                            message: "EyeBreak could not schedule the reminder notification.\n\n\(error.localizedDescription)"
                        )
                        return
                    }

                    self.scheduler.remindNow()
                    self.refreshStatusItem()
                    self.rebuildMenu()
                }
            }
        }
    }

    private func requestNotificationPermission() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, _ in
            if !granted {
                Task { @MainActor in
                    self?.showNotificationPermissionWarning()
                }
            }
        }
    }

    private func showNotificationPermissionWarning() {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Notifications are turned off"
        alert.informativeText = "Enable notifications for EyeBreak in System Settings so reminders can appear."
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    private func refreshStatusItem() {
        guard let button = statusItem.button else {
            return
        }

        let status = scheduler.status()
        button.image = image(for: status)
        button.toolTip = statusText(for: status)
    }

    private func image(for status: ReminderState) -> NSImage? {
        let symbolName: String
        switch status {
        case .disabled:
            symbolName = "pause.circle"
        case .snoozed:
            symbolName = "moon.zzz"
        case .waiting:
            symbolName = "eye"
        }

        return NSImage(systemSymbolName: symbolName, accessibilityDescription: "EyeBreak")
    }

    private func statusText(for status: ReminderState) -> String {
        switch status {
        case .disabled:
            return "EyeBreak is turned off"
        case let .snoozed(until):
            return "Snoozed until \(timeFormatter.string(from: until))"
        case let .waiting(next):
            return "Next reminder at \(timeFormatter.string(from: next))"
        }
    }

    private func rebuildMenu() {
        menu.removeAllItems()

        let statusItem = NSMenuItem(title: statusText(for: scheduler.status()), action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)

        let activeWindowItem = NSMenuItem(
            title: "Active daily: \(scheduler.formattedActiveWindow())",
            action: nil,
            keyEquivalent: ""
        )
        activeWindowItem.isEnabled = false
        menu.addItem(activeWindowItem)

        menu.addItem(.separator())

        let enabledItem = NSMenuItem(title: "Enabled", action: #selector(toggleEnabled(_:)), keyEquivalent: "")
        enabledItem.target = self
        enabledItem.state = scheduler.settings.isEnabled ? .on : .off
        menu.addItem(enabledItem)

        let snoozeItem = NSMenuItem(
            title: "Snooze \(scheduler.settings.snoozeMinutes) min",
            action: #selector(snoozeReminder(_:)),
            keyEquivalent: ""
        )
        snoozeItem.target = self
        snoozeItem.isEnabled = scheduler.settings.isEnabled
        menu.addItem(snoozeItem)

        let remindNowItem = NSMenuItem(title: "Remind Now", action: #selector(remindNow(_:)), keyEquivalent: "")
        remindNowItem.target = self
        remindNowItem.isEnabled = scheduler.settings.isEnabled
        menu.addItem(remindNowItem)

        menu.addItem(.separator())
        menu.addItem(buildIntervalMenuItem())
        menu.addItem(buildSnoozeMenuItem())

        let activeHoursItem = NSMenuItem(title: "Set Active Hours...", action: #selector(configureActiveHours(_:)), keyEquivalent: "")
        activeHoursItem.target = self
        menu.addItem(activeHoursItem)

        let launchAtLoginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin(_:)), keyEquivalent: "")
        launchAtLoginItem.target = self
        launchAtLoginItem.state = launchAtLoginEnabled ? .on : .off
        menu.addItem(launchAtLoginItem)

        if SMAppService.mainApp.status == .requiresApproval {
            let approvalItem = NSMenuItem(title: "Approval needed in System Settings > Login Items", action: nil, keyEquivalent: "")
            approvalItem.isEnabled = false
            menu.addItem(approvalItem)
        }

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit EyeBreak", action: #selector(quitApp(_:)), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    private func buildIntervalMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Reminder Interval", action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: "Reminder Interval")

        for minutes in Constants.intervalPresets {
            let presetItem = NSMenuItem(
                title: "\(minutes) min",
                action: #selector(updateInterval(_:)),
                keyEquivalent: ""
            )
            presetItem.target = self
            presetItem.tag = minutes
            presetItem.state = scheduler.settings.intervalMinutes == minutes ? .on : .off
            submenu.addItem(presetItem)
        }

        submenu.addItem(.separator())

        let customItem = NSMenuItem(title: "Custom...", action: #selector(customInterval(_:)), keyEquivalent: "")
        customItem.target = self
        let hasPreset = Constants.intervalPresets.contains(scheduler.settings.intervalMinutes)
        customItem.state = hasPreset ? .off : .on
        submenu.addItem(customItem)

        item.submenu = submenu
        return item
    }

    private func buildSnoozeMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Default Snooze", action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: "Default Snooze")

        for minutes in Constants.snoozePresets {
            let presetItem = NSMenuItem(
                title: "\(minutes) min",
                action: #selector(updateSnoozeLength(_:)),
                keyEquivalent: ""
            )
            presetItem.target = self
            presetItem.tag = minutes
            presetItem.state = scheduler.settings.snoozeMinutes == minutes ? .on : .off
            submenu.addItem(presetItem)
        }

        submenu.addItem(.separator())

        let customItem = NSMenuItem(title: "Custom...", action: #selector(customSnoozeLength(_:)), keyEquivalent: "")
        customItem.target = self
        let hasPreset = Constants.snoozePresets.contains(scheduler.settings.snoozeMinutes)
        customItem.state = hasPreset ? .off : .on
        submenu.addItem(customItem)

        item.submenu = submenu
        return item
    }

    private func promptForMinutes(title: String, message: String, initialValue: Int) -> Int? {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let textField = NSTextField(string: "\(initialValue)")
        textField.frame = NSRect(x: 0, y: 0, width: 200, height: 24)
        textField.alignment = .center
        alert.accessoryView = textField

        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else {
            return nil
        }

        let value = Int(textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines))
        guard let value, value > 0 else {
            return nil
        }

        return value
    }

    private func promptForActiveHours(startHour: Int, endHour: Int) -> (start: Int, end: Int)? {
        let alert = NSAlert()
        alert.messageText = "Active Hours"
        alert.informativeText = "Choose the daily reminder window using 24-hour time."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let container = NSView(frame: NSRect(x: 0, y: 0, width: 240, height: 56))
        let startField = NSTextField(string: "\(startHour)")
        startField.placeholderString = "Start hour"
        startField.frame = NSRect(x: 0, y: 28, width: 110, height: 24)

        let endField = NSTextField(string: "\(endHour)")
        endField.placeholderString = "End hour"
        endField.frame = NSRect(x: 130, y: 28, width: 110, height: 24)

        let hint = NSTextField(labelWithString: "Example: 8 to 20 means 8:00 AM through 8:00 PM.")
        hint.frame = NSRect(x: 0, y: 0, width: 240, height: 20)
        hint.lineBreakMode = .byWordWrapping

        container.addSubview(startField)
        container.addSubview(endField)
        container.addSubview(hint)
        alert.accessoryView = container

        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else {
            return nil
        }

        guard
            let start = Int(startField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)),
            let end = Int(endField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)),
            start >= 0,
            start <= 23,
            end >= 1,
            end <= 24,
            start < end
        else {
            return nil
        }

        return (start, end)
    }

    private var launchAtLoginEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    private func applyAppIcon() {
        guard let icon = Bundle.main.image(forResource: "AppIcon") else {
            return
        }

        NSApplication.shared.applicationIconImage = icon
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
