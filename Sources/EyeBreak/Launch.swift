import AppKit

@MainActor
private final class AppRuntime {
    static let shared = AppRuntime()
    var delegate: AppDelegate?
}

@MainActor
@main
enum EyeBreakLauncher {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()

        AppRuntime.shared.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.delegate = delegate
        app.run()
    }
}
