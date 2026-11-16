import Foundation
import Combine

/// Global application state
@MainActor
class AppState: ObservableObject {
    
    enum AppMode: String, CaseIterable {
        case safe = "safe"
        case experimental = "experimental"
    }
    
    @Published var currentMode: AppMode = .safe
    @Published var isInitialized: Bool = false
    @Published var selectedTab: Tab = .chat
    
    enum Tab: Int, CaseIterable {
        case chat = 0
        case models = 1
        case performance = 2
        case settings = 3
    }
    
    func initialize() {
        // Ensure model directories exist
        let fm = FileManager.default
        
        do {
            try fm.createDirectory(at: AppConfiguration.modelsDirectory,
                                   withIntermediateDirectories: true)
            try fm.createDirectory(at: AppConfiguration.downloadsDirectory,
                                   withIntermediateDirectories: true)
        } catch {
            print("[AppState] Failed to create directories: \(error)")
        }
        
        isInitialized = true
    }
}
