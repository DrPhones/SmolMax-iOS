import Foundation

/// Inference parameters
struct InferenceParameters: Codable {
    var cpuThreads: Int
    var contextLength: Int
    var temperature: Float
    var topP: Float
    var topK: Int
    var repeatPenalty: Float
    var expertPoolSize: Int
    var enablePrefetch: Bool
    var routingBias: Float
    var useGPU: Bool
    var memorySafetyMode: Bool
    
    /// Create safe-mode defaults
    static var safe: InferenceParameters {
        InferenceParameters(
            cpuThreads: AppConfiguration.SafeDefaults.cpuThreads,
            contextLength: AppConfiguration.SafeDefaults.contextLength,
            temperature: AppConfiguration.SafeDefaults.temperature,
            topP: AppConfiguration.SafeDefaults.topP,
            topK: AppConfiguration.SafeDefaults.topK,
            repeatPenalty: AppConfiguration.SafeDefaults.repeatPenalty,
            expertPoolSize: AppConfiguration.SafeDefaults.expertPoolSize,
            enablePrefetch: AppConfiguration.SafeDefaults.enablePrefetch,
            routingBias: AppConfiguration.SafeDefaults.routingBias,
            useGPU: AppConfiguration.SafeDefaults.useGPU,
            memorySafetyMode: true
        )
    }
    
    /// Create experimental-mode defaults
    static var experimental: InferenceParameters {
        InferenceParameters(
            cpuThreads: AppConfiguration.ExperimentalDefaults.cpuThreads,
            contextLength: AppConfiguration.ExperimentalDefaults.contextLength,
            temperature: AppConfiguration.ExperimentalDefaults.temperature,
            topP: AppConfiguration.ExperimentalDefaults.topP,
            topK: AppConfiguration.ExperimentalDefaults.topK,
            repeatPenalty: AppConfiguration.ExperimentalDefaults.repeatPenalty,
            expertPoolSize: AppConfiguration.ExperimentalDefaults.expertPoolSize,
            enablePrefetch: AppConfiguration.ExperimentalDefaults.enablePrefetch,
            routingBias: AppConfiguration.ExperimentalDefaults.routingBias,
            useGPU: AppConfiguration.ExperimentalDefaults.useGPU,
            memorySafetyMode: false
        )
    }
}

/// Real-time inference metrics
struct InferenceMetrics {
    var tokensPerSecond: Double = 0
    var timeToFirstToken: Double = 0
    var promptTokensPerSecond: Double = 0
    var currentMemoryFootprint: UInt64 = 0
    var availableProcessMemory: UInt64 = 0
    var expertCacheHitRate: Double = 0
    var expertCacheMissRate: Double = 0
    var loadedExpertCount: Int = 0
    var storageReadsCount: UInt64 = 0
    var diskThroughput: Double = 0 // MB/s
    var thermalState: ThermalState = .nominal
    var totalTokensGenerated: Int = 0
    var isGenerating: Bool = false
    
    enum ThermalState: String {
        case nominal = "Nominal"
        case fair = "Fair"
        case serious = "Serious"
        case critical = "Critical"
    }
}

/// Memory information utility
struct MemoryInfo {
    /// Get current available memory using os_proc_available_memory()
    static var currentAvailable: UInt64 {
        return os_proc_available_memory()
    }
    
    /// Get physical memory
    static var physicalMemory: UInt64 {
        return ProcessInfo.processInfo.physicalMemory
    }
    
    /// Calculate safe memory budget for model loading
    static var safeBudget: UInt64 {
        let available = currentAvailable
        let reserve = UInt64(Double(available) * AppConfiguration.memoryReserveFraction)
        return available - reserve
    }
    
    /// Whether the device can accommodate the given memory requirement
    static func canAccommodate(bytes: UInt64) -> Bool {
        return bytes < safeBudget
    }
}

/// Import from Darwin for os_proc_available_memory
@_silgen_name("os_proc_available_memory")
func os_proc_available_memory() -> UInt64
