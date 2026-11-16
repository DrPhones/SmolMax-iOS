import Foundation

/// Buffers and smooths incoming token pieces for fluid UI rendering
class TokenStreamer: ObservableObject {
    @Published var streamedText: String = ""
    private var pendingQueue: [String] = []
    private var isFlushing: Bool = false
    
    func reset() {
        streamedText = ""
        pendingQueue.removeAll()
    }
    
    func append(piece: String) {
        streamedText.append(piece)
    }
}
