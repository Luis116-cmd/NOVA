import Foundation

public enum ArtifactKind {
    case studyGuide
    case summary
    case notes
}

public actor NOVABrain {
    private var conversationHistory: [[String: String]] = []
    private let historyFilePath: URL

    private let systemPrompt = """
    You are NOVA, a mature, articulate, and highly competent personal AI assistant.
    Speak naturally with composure, clarity, and intelligence. Maintain a grounded, thoughtful tone—avoid childish energy, overly casual slang, or robotic fluff.
    Keep spoken responses concise, clear, and direct. Do not read aloud special formatting characters like asterisks.

    STRICT ACCURACY & GROUNDING RULES:
    1. Never fabricate or invent personal facts, upcoming tests, assignments, schedules, or events unless explicitly stated by the user.
    2. If you do not have information about something, acknowledge what you know based on the conversation history or ask for clarification.
    """

    public init(preferences: Any? = nil) {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        self.historyFilePath = paths[0].appendingPathComponent("nova_history.json")
        Task {
            await self.loadHistoryFromDisk()
        }
    }

    public func reply(to prompt: String) async throws -> String {
        return await askOllama(prompt: prompt)
    }

    public func askOllama(prompt: String) async -> String {
        conversationHistory.append(["role": "user", "content": prompt])
        
        if conversationHistory.count > 20 {
            conversationHistory.removeFirst(conversationHistory.count - 20)
        }
        
        saveHistoryToDisk()

        var messages: [[String: String]] = [["role": "system", "content": systemPrompt]]
        messages.append(contentsOf: conversationHistory)

        guard let url = URL(string: "http://localhost:11434/api/chat") else {
            return "Server URL error."
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": "llama3:8b",
            "messages": messages,
            "stream": false
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: request)

            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                return "I couldn't reach Ollama. Make sure Ollama is running in the background."
            }

            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let messageObj = json["message"] as? [String: Any],
               let content = messageObj["content"] as? String {
                
                let cleanedResponse = content.trimmingCharacters(in: .whitespacesAndNewlines)
                conversationHistory.append(["role": "assistant", "content": cleanedResponse])
                saveHistoryToDisk()
                return cleanedResponse
            }
        } catch {
            return "Connection error: \(error.localizedDescription)"
        }

        return "I didn't receive a valid response."
    }

    public func artifact(topic: String, kind: ArtifactKind) async -> String {
        let prompt = "Create a comprehensive study guide on the topic: \(topic)."
        return await askOllama(prompt: prompt)
    }

    public func flashcards(topic: String) async -> [(String, String)] {
        let prompt = "Create 5 flashcards on \(topic). Format each line exactly as: Question | Answer"
        let response = await askOllama(prompt: prompt)
        
        var pairs: [(String, String)] = []
        let lines = response.components(separatedBy: "\n")
        for line in lines {
            let parts = line.components(separatedBy: "|")
            if parts.count == 2 {
                let q = parts[0].trimmingCharacters(in: .whitespaces)
                let a = parts[1].trimmingCharacters(in: .whitespaces)
                pairs.append((q, a))
            }
        }
        
        if pairs.isEmpty {
            pairs.append(("What is \(topic)?", "Key details about \(topic)."))
        }
        return pairs
    }

    public func clearMemory() {
        conversationHistory.removeAll()
        saveHistoryToDisk()
    }

    private func saveHistoryToDisk() {
        do {
            let data = try JSONSerialization.data(withJSONObject: conversationHistory, options: .prettyPrinted)
            try data.write(to: historyFilePath)
        } catch {
            print("Failed to save memory: \(error)")
        }
    }

    private func loadHistoryFromDisk() {
        do {
            if FileManager.default.fileExists(atPath: historyFilePath.path) {
                let data = try Data(contentsOf: historyFilePath)
                if let loaded = try JSONSerialization.jsonObject(with: data) as? [[String: String]] {
                    self.conversationHistory = loaded
                }
            }
        } catch {
            print("Failed to load memory: \(error)")
        }
    }
}
