import SwiftUI

struct ChatView: View {
    @EnvironmentObject var inferenceManager: InferenceManager
    @EnvironmentObject var modelManager: ModelManager
    @ObservedObject var loc = LocalizationManager.shared
    
    @State private var inputPrompt: String = ""
    @State private var currentConversation = ChatConversation()
    @State private var isAutoScrollEnabled = true
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Model Status Bar
                modelStatusBar
                
                // Chat Message List
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            if currentConversation.messages.isEmpty {
                                emptyStateView
                            } else {
                                ForEach(currentConversation.messages) { message in
                                    ChatMessageRow(message: message) { _ in }
                                        .id(message.id)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .onChange(of: currentConversation.messages.last?.content) { _ in
                        if isAutoScrollEnabled, let lastId = currentConversation.messages.last?.id {
                            withAnimation(.easeOut(duration: 0.2)) {
                                proxy.scrollTo(lastId, anchor: .bottom)
                            }
                        }
                    }
                }
                
                // Bottom Input & Control Bar
                inputBar
            }
            .navigationTitle(loc.localized("app_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: clearChat) {
                        Image(systemName: "trash")
                            .foregroundColor(.secondary)
                    }
                    .disabled(inferenceManager.isGenerating || currentConversation.messages.isEmpty)
                }
            }
        }
        .environment(\.layoutDirection, loc.layoutDirection)
    }
    
    // MARK: - Subviews
    
    private var modelStatusBar: some View {
        HStack {
            Circle()
                .fill(inferenceManager.isModelLoaded ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
            
            Text(inferenceManager.currentModelName ?? loc.localized("no_model_loaded"))
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
            
            Spacer()
            
            if inferenceManager.isGenerating {
                Text(String(format: "%.1f tok/s", inferenceManager.metrics.tokensPerSecond))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.tertiarySystemBackground))
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text(loc.localized("app_title"))
                .font(.headline)
            
            Text(inferenceManager.isModelLoaded ?
                 loc.localized("message_placeholder") :
                 loc.localized("select_model_prompt"))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(.top, 80)
    }
    
    private var inputBar: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(spacing: 12) {
                TextField(loc.localized("message_placeholder"), text: $inputPrompt, axis: .vertical)
                    .lineLimit(1...5)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(18)
                    .disabled(!inferenceManager.isModelLoaded || inferenceManager.isGenerating)
                
                if inferenceManager.isGenerating {
                    Button(action: stopGeneration) {
                        Image(systemName: "stop.fill")
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.red)
                            .clipShape(Circle())
                    }
                } else {
                    Button(action: sendMessage) {
                        Image(systemName: "arrow.up")
                            .foregroundColor(.white)
                            .padding(10)
                            .background(canSend ? Color.blue : Color.gray)
                            .clipShape(Circle())
                    }
                    .disabled(!canSend)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(.systemBackground))
        }
    }
    
    private var canSend: Bool {
        return inferenceManager.isModelLoaded && !inputPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // MARK: - Actions
    
    private func sendMessage() {
        let text = inputPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        inputPrompt = ""
        
        let userMessage = ChatMessage(role: .user, content: text)
        currentConversation.messages.append(userMessage)
        
        // Placeholder assistant message
        let assistantMessage = ChatMessage(role: .assistant, content: "", isGenerating: true)
        currentConversation.messages.append(assistantMessage)
        
        Task {
            await inferenceManager.generateResponse(conversation: currentConversation) { token in
                if let lastIdx = currentConversation.messages.indices.last {
                    currentConversation.messages[lastIdx].content.append(token)
                }
            }
            if let lastIdx = currentConversation.messages.indices.last {
                currentConversation.messages[lastIdx].isGenerating = false
            }
        }
    }
    
    private func stopGeneration() {
        inferenceManager.stop()
        if let lastIdx = currentConversation.messages.indices.last {
            currentConversation.messages[lastIdx].isGenerating = false
        }
    }
    
    private func clearChat() {
        currentConversation = ChatConversation()
    }
}
