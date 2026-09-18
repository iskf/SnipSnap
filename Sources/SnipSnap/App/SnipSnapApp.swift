import Cocoa

@main
public struct SnipSnapMain {
    public static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
