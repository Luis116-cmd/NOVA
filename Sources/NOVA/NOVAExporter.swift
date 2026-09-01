import Foundation

enum NOVAExporter {
    private static var exportDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("NOVA/Exports", isDirectory: true)
    }

    static func saveStudyGuide(topic: String, body: String) throws -> URL {
        try FileManager.default.createDirectory(at: exportDirectory, withIntermediateDirectories: true)
        let title = clean(topic)
        let content = "# Study Guide: \(topic)\n\nCreated by NOVA on \(Date().formatted(date: .long, time: .shortened))\n\n\(body)\n"
        let url = exportDirectory.appendingPathComponent("Study Guide — \(title).md")
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    static func saveFlashcards(topic: String, cards: [(String, String)]) throws -> URL {
        try FileManager.default.createDirectory(at: exportDirectory, withIntermediateDirectories: true)
        let rows = cards.map { "\(sanitize($0.0))\t\(sanitize($0.1))" }.joined(separator: "\n") + "\n"
        let url = exportDirectory.appendingPathComponent("Flashcards — \(clean(topic)).tsv")
        try rows.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private static func sanitize(_ value: String) -> String { value.replacingOccurrences(of: "\t", with: " ").replacingOccurrences(of: "\n", with: " ") }
    private static func clean(_ text: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(.whitespaces)
        let cleaned = text.unicodeScalars.map { allowed.contains($0) ? Character(String($0)) : " " }
        return String(cleaned).split(separator: " ").prefix(8).joined(separator: " ").isEmpty ? "Untitled" : String(String(cleaned).split(separator: " ").prefix(8).joined(separator: " "))
    }
}

enum NOVAFallbackMaterial {
    static func studyGuide(topic: String) -> String {
        """
        ## Learning goals
        - Define the central ideas in \(topic).
        - Explain how the ideas connect using your own examples.
        - Identify what you still need to verify from class materials.

        ## Core concept map
        **\(topic)** → definitions → mechanisms/processes → examples → common errors → self-test.

        ## Study method
        1. Read your course notes and write three precise definitions.
        2. Draw the process or relationship from memory.
        3. Teach it aloud in two minutes, then compare against your source material.
        4. Turn missed details into flashcards.

        ## Common mistakes
        - Memorizing labels without explaining relationships.
        - Treating one example as the rule.
        - Skipping source verification for dates, formulas, or technical facts.

        ## Self-test
        1. What is the simplest accurate definition of \(topic)?
        2. What causes the main process or change?
        3. What is a useful counterexample?
        4. Which terms are easy to confuse?
        5. How would you explain it to a classmate?

        **Answers:** Use your assigned materials to verify each answer; this offline template deliberately avoids inventing subject-specific facts.
        """
    }

    static func flashcards(topic: String) -> [(String, String)] {
        [
            ("What is the central question in \(topic)?", "State it in one clear sentence from your course materials."),
            ("What are the three most important terms in \(topic)?", "Define each precisely and distinguish them."),
            ("What causes the key process in \(topic)?", "Identify the mechanism, not just an example."),
            ("What is an example of \(topic)?", "Choose an example your instructor used."),
            ("What is a non-example of \(topic)?", "A related case that does not meet the definition."),
            ("What is commonly confused with \(topic)?", "Name the similar concept and the decisive difference."),
            ("How would you test your understanding of \(topic)?", "Explain it without notes, then verify against the source."),
            ("What evidence supports the main idea in \(topic)?", "Use a verified course source, data point, or worked example."),
            ("What assumption appears in \(topic)?", "State the assumption and when it might fail."),
            ("How does \(topic) connect to the previous unit?", "Describe one causal, structural, or historical link.")
        ]
    }
}