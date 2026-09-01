import Foundation
import AppKit

@MainActor
public final class NOVASettingsPresenter {
    public static func show(from window: NSWindow?, coordinator: NOVACoordinator) {
        let alert = NSAlert()
        alert.messageText = "NOVA Settings"
        alert.informativeText = "Voice enabled: \(coordinator.preferences.voiceEnabled ? "On" : "Off")\nLocal model: \(coordinator.preferences.localModel)"
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
