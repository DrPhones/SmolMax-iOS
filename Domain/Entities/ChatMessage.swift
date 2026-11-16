import Foundation

/// Represents a single chat message
struct ChatMessage: Identifiable, Codable {
    let id: UUID
    let role: Role
    var content: String
    let timestamp: Date
    var isGenerating: Bool
    
    enum Role: String, Codable {
        case user
        case assistant
        case system
    }
    
    init(id: UUID = UUID(), role: Role, content: String, timestamp: Date = Date(), isGenerating: Bool = false) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.isGenerating = isGenerating
    }
}

/// A complete chat conversation
struct ChatConversation: Identifiable, Codable {
    let id: UUID
    var title: String
    var messages: [ChatMessage]
    var modelName: String?
    let createdDate: Date
    var lastModifiedDate: Date
    
    init(id: UUID = UUID(), title: String = "", messages: [ChatMessage] = [], modelName: String? = nil) {
        self.id = id
        self.title = title
        self.messages = messages
        self.modelName = modelName
        self.createdDate = Date()
        self.lastModifiedDate = Date()
    }
    
    /// Generate a title from the first user message
    mutating func autoTitle() {
        if title.isEmpty, let firstUserMessage = messages.first(where: { $0.role == .user }) {
            let text = firstUserMessage.content
            title = String(text.prefix(50))
            if text.count > 50 { title += "…" }
        }
    }
}
