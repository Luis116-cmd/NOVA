import AppKit
import Foundation

enum NOVAActionRequest {
    case openApp(MacApplication)
    case studyGuide(String)
    case flashcards(String)
    case blocked(String)

    static func parse(_ text: String) -> NOVAActionRequest? {
        let normal = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if normal.contains("delete ") || normal.contains("erase ") || normal.contains("terminal") || normal.contains("run shell") || normal.contains("system setting") || normal.contains("password") {
            return .blocked("I don’t run destructive commands, terminal commands, system changes, or anything involving passwords from conversation. I can help you plan a safe, reviewable next step instead.")
        }
        for app in MacApplication.allCases where normal.contains("open \(app.rawValue)") || normal == app.rawValue {
            return .openApp(app)
        }
        if let topic = captureTopic(in: text, terms: ["study guide", "studyguide"]) { return .studyGuide(topic) }
        if let topic = captureTopic(in: text, terms: ["flashcards", "flash cards"]) { return .flashcards(topic) }
        return nil
    }

    private static func captureTopic(in text: String, terms: [String]) -> String? {
        let lowered = text.lowercased()
        guard let term = terms.first(where: { lowered.contains($0) }) else { return nil }
        let after = String(text[lowered.range(of: term)!.upperBound...])
            .replacingOccurrences(of: "for", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "about", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        return after.isEmpty ? "your topic" : after
    }
}

enum MacApplication: String, CaseIterable {
    case safari, calendar, notes, finder, mail, messages, music, preview, pages, numbers, keynotes

    var bundleIdentifier: String {
        switch self {
        case .safari: "com.apple.Safari"; case .calendar: "com.apple.iCal"; case .notes: "com.apple.Notes"
        case .finder: "com.apple.finder"; case .mail: "com.apple.mail"; case .messages: "com.apple.MobileSMS"
        case .music: "com.apple.Music"; case .preview: "com.apple.Preview"; case .pages: "com.apple.iWork.Pages"
        case .numbers: "com.apple.iWork.Numbers"; case .keynotes: "com.apple.iWork.Keynote"
        }
    }
}

final class MacActionEngine {
    struct Result { let message: String }
    func open(_ application: MacApplication, completion: @escaping (Result) -> Void) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: application.bundleIdentifier) else {
            completion(Result(message: "I couldn’t find \(application.rawValue.capitalized) on this Mac."))
            return
        }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: config) { _, _ in }
        completion(Result(message: "Asked macOS to open \(application.rawValue.capitalized)."))
    }
}