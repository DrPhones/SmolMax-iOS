import Foundation

/// Use case for handling chat interactions and streaming responses
class GenerateChatResponseUseCase {
    private let engine: InferenceEngineProtocol
    private let memoryManager: MemoryManagerProtocol
    
    init(engine: InferenceEngineProtocol, memoryManager: MemoryManagerProtocol) {
        self.engine = engine
        self.memoryManager = memoryManager
    }
    
    /// Stream a response for the full conversation history
    func execute(conversation: ChatConversation, parameters: InferenceParameters) -> AsyncThrowingStream<String, Error> {
        // Build prompt with standard chat template format
        let prompt = formatChatPrompt(messages: conversation.messages)
        
        // Check memory pressure before starting
        if memoryManager.memoryPressureLevel == .critical {
            return AsyncThrowingStream { continuation in
                continuation.finish(throwing: NSError(
                    domain: "SmolMax.Chat",
                    code: 503,
                    userInfo: [NSLocalizedDescriptionKey: "Inference paused: Device under critical memory pressure"]
                ))
            }
        }
        
        return engine.generate(prompt: prompt, parameters: parameters)
    }
    
    func stop() {
        engine.stopGeneration()
    }
    
    private func formatChatPrompt(messages: [ChatMessage]) -> String {
        var formatted = ""
        for message in messages {
            switch message.role {
            case .system:
                formatted += "<|im_start|>system\n\(message.content)<|im_end|>\n"
            case .user:
                formatted += "<|im_start|>user\n\(message.content)<|im_end|>\n"
            case .assistant:
                formatted += "<|im_start|>assistant\n\(message.content)<|im_end|>\n"
            }
        }
        // Signal assistant start
        formatted += "<|im_start|>assistant\n"
        return formatted
    }
}
