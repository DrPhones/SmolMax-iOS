import Foundation

/// Persistent local storage for chat conversations
class ChatStorage {
    private let storageURL: URL
    
    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.storageURL = docs.appendingPathComponent("conversations.json")
    }
    
    func loadConversations() -> [ChatConversation] {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return [] }
        do {
            let data = try Data(contentsOf: storageURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([ChatConversation].self, from: data)
        } catch {
            print("[ChatStorage] Failed to load conversations: \(error)")
            return []
        }
    }
    
    func saveConversations(_ conversations: [ChatConversation]) {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(conversations)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            print("[ChatStorage] Failed to save conversations: \(error)")
        }
    }
}
