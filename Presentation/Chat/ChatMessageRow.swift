import SwiftUI

/// A message bubble in the chat view with RTL/LTR awareness and copy actions
struct ChatMessageRow: View {
    let message: ChatMessage
    let onCopy: (String) -> Void
    
    @State private var showCopiedAlert = false
    
    private var isUser: Bool {
        return message.role == .user
    }
    
    // Auto-detect text direction based on first strong character
    private var isTextArabic: Bool {
        for scalar in message.content.unicodeScalars {
            if (0x0600...0x06FF).contains(scalar.value) || (0x0750...0x077F).contains(scalar.value) {
                return true
            }
        }
        return false
    }
    
    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 40) }
            
            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if !isUser {
                        Image(systemName: "cpu")
                            .font(.caption)
                            .foregroundColor(.purple)
                    }
                    Text(isUser ? "أنت" : "SmolMax")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: isTextArabic ? .trailing : .leading, spacing: 8) {
                    Text(message.content)
                        .font(.body)
                        .foregroundColor(isUser ? .white : .primary)
                        .multilineTextAlignment(isTextArabic ? .trailing : .leading)
                        .environment(\.layoutDirection, isTextArabic ? .rightToLeft : .leftToRight)
                        .textSelection(.enabled)
                    
                    if message.isGenerating {
                        HStack(spacing: 4) {
                            Circle().fill(Color.purple).frame(width: 6, height: 6)
                            Circle().fill(Color.purple.opacity(0.6)).frame(width: 6, height: 6)
                            Circle().fill(Color.purple.opacity(0.3)).frame(width: 6, height: 6)
                        }
                        .padding(.top, 2)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(isUser ? Color.blue : Color(.secondarySystemBackground))
                .cornerRadius(16)
                .contextMenu {
                    Button(action: {
                        UIPasteboard.general.string = message.content
                        onCopy(message.content)
                    }) {
                        Label("نسخ النص", systemImage: "doc.on.doc")
                    }
                }
            }
            
            if !isUser { Spacer(minLength: 40) }
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
    }
}
