import Foundation

/// Central application configuration
struct AppConfiguration {
    
    // MARK: - Memory Budget
    
    /// Safety margin: reserve this fraction of available memory for the system
    static let memoryReserveFraction: Double = 0.25
    
    /// Minimum available memory before refusing to load a model (bytes)
    static let minimumAvailableMemory: UInt64 = 200 * 1024 * 1024 // 200MB
    
    /// Maximum expert cache size as fraction of available memory
    static let maxExpertCacheFraction: Double = 0.5
    
    // MARK: - Inference Defaults (Safe Mode)
    
    struct SafeDefaults {
        static let cpuThreads: Int = 4
        static let contextLength: Int = 2048
        static let temperature: Float = 0.7
        static let topP: Float = 0.9
        static let topK: Int = 40
        static let repeatPenalty: Float = 1.1
        static let expertPoolSize: Int = 4
        static let enablePrefetch: Bool = true
        static let routingBias: Float = 0.0 // No bias = exact routing
        static let useGPU: Bool = false // CPU-first for memory safety
    }
    
    // MARK: - Inference Defaults (Experimental Mode)
    
    struct ExperimentalDefaults {
        static let cpuThreads: Int = 6
        static let contextLength: Int = 4096
        static let temperature: Float = 0.7
        static let topP: Float = 0.9
        static let topK: Int = 40
        static let repeatPenalty: Float = 1.1
        static let expertPoolSize: Int = 8
        static let enablePrefetch: Bool = true
        static let routingBias: Float = 0.0
        static let useGPU: Bool = true
    }
    
    // MARK: - Storage
    
    /// Directory name for stored models within app sandbox
    static let modelsDirectoryName = "Models"
    
    /// Directory name for temporary downloads
    static let downloadsDirectoryName = "Downloads"
    
    /// Minimum free storage required before allowing model import (bytes)
    static let minimumFreeStorage: UInt64 = 500 * 1024 * 1024 // 500MB
    
    // MARK: - Model Import
    
    /// Supported file extensions for model import
    static let supportedModelExtensions = ["gguf"]
    
    /// Maximum file size for single GGUF import attempt (informational, not hard limit)
    static let largeFileWarningThreshold: UInt64 = 4 * 1024 * 1024 * 1024 // 4GB
    
    // MARK: - Paths
    
    static var modelsDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent(modelsDirectoryName)
    }
    
    static var downloadsDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent(downloadsDirectoryName)
    }
    
    // MARK: - Build Info
    
    static let llamaCppCommit = "PINNED_AFTER_RESEARCH" // Will be set after repo analysis
    static let smolmaxxingCommit = "PINNED_AFTER_RESEARCH"
}
