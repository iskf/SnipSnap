import Cocoa
import SwiftUI

public typealias PreferencesSubTab = ControlCenterSubTab

public class PreferencesWindowController: NSWindowController {
    public static func show() {
        MainControlWindowController.show(tab: .general)
    }
}

public struct PreferencesView: View {
    public init() {}
    public var body: some View {
        MainControlView(viewModel: MainControlViewModel(selectedTab: .general))
    }
}
