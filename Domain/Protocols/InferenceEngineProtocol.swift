import Foundation
import Combine

/// Protocol defining the inference engine interface
protocol InferenceEngineProtocol: AnyObject {
    /// Current state of the engine
    var isModelLoaded: Bool { get }
    var currentModel: LLMModel? { get }
    var metrics: InferenceMetrics { get }
    
    /// Load a model from file path with specified parameters
    func loadModel(at url: URL, parameters: InferenceParameters) async throws
    
    /// Unload the currently loaded model and free resources
    func unloadModel() async
    
    /// Generate a streaming response for the given prompt
    func generate(prompt: String, parameters: InferenceParameters) -> AsyncThrowingStream<String, Error>
    
    /// Stop ongoing generation immediately
    func stopGeneration()
    
    /// Flush KV cache to release memory
    func clearKVCache()
    
    /// Configure expert paging options (MoE only)
    func configureExpertPaging(poolSize: Int, enablePrefetch: Bool, routingBias: Float)
}

/// Protocol for model repository and discovery
protocol ModelRepositoryProtocol {
    func listModels() async throws -> [LLMModel]
    func importModel(from sourceURL: URL) async throws -> LLMModel
    func deleteModel(id: UUID) async throws
    func getModel(id: UUID) async throws -> LLMModel?
    func validateGGUF(at url: URL) throws -> (architecture: ModelArchitecture, quant: QuantizationType, isMoE: Bool, paramCount: String)
}

/// Protocol for device memory tracking and safety management
protocol MemoryManagerProtocol: AnyObject {
    var availableMemory: UInt64 { get }
    var physicalMemory: UInt64 { get }
    var memoryPressureLevel: MemoryPressureLevel { get }
    var safeMemoryBudget: UInt64 { get }
    
    func canLoadModel(fileSize: UInt64, isMoE: Bool, expertPoolSize: Int) -> Bool
    func registerMemoryPressureHandler(_ handler: @escaping (MemoryPressureLevel) -> Void)
    func requestEmergencyMemoryRelease()
}

enum MemoryPressureLevel: String {
    case normal = "Normal"
    case warning = "Warning"
    case critical = "Critical"
}
