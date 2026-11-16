import Foundation
import Combine

/// Swift wrapper providing async/await interface over the Objective-C++ LlamaBridge
class LlamaContext: ObservableObject, InferenceEngineProtocol {
    private let bridge: LlamaBridge
    
    @Published var isModelLoaded: Bool = false
    @Published var currentModel: LLMModel?
    @Published var metrics: InferenceMetrics = InferenceMetrics()
    
    private var cancellables = Set<AnyCancellable>()
    private var timer: Timer?
    
    init() {
        self.bridge = LlamaBridge()
        startMetricsPolling()
    }
    
    deinit {
        timer?.invalidate()
        bridge.unloadModel()
    }
    
    func loadModel(at url: URL, parameters: InferenceParameters) async throws {
        let isMoE = url.lastPathComponent.lowercased().contains("moe") ||
                    url.lastPathComponent.lowercased().contains("ling") ||
                    url.lastPathComponent.lowercased().contains("a3b")
        
        var loadError: NSError?
        let success = bridge.loadModel(
            withPath: url.path,
            contextSize: parameters.contextLength,
            threads: parameters.cpuThreads,
            useGPU: parameters.useGPU,
            isMoE: isMoE,
            expertPoolSize: parameters.expertPoolSize,
            error: &loadError
        )
        
        guard success else {
            throw loadError ?? NSError(domain: "SmolMax.Engine", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to initialize engine"])
        }
        
        await MainActor.run {
            self.isModelLoaded = bridge.isModelLoaded
        }
    }
    
    func unloadModel() async {
        bridge.unloadModel()
        await MainActor.run {
            self.isModelLoaded = false
            self.currentModel = nil
        }
    }
    
    func generate(prompt: String, parameters: InferenceParameters) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            bridge.generate(
                withPrompt: prompt,
                temperature: parameters.temperature,
                topP: parameters.topP,
                topK: Int32(parameters.topK),
                repeatPenalty: parameters.repeatPenalty,
                onToken: { piece in
                    continuation.yield(piece)
                },
                onComplete: {
                    continuation.finish()
                },
                onError: { error in
                    continuation.finish(throwing: error)
                }
            )
        }
    }
    
    func stopGeneration() {
        bridge.stopGeneration()
    }
    
    func clearKVCache() {
        bridge.clearKVCache()
    }
    
    func configureExpertPaging(poolSize: Int, enablePrefetch: Bool, routingBias: Float) {
        bridge.configureExpertPaging(withPoolSize: poolSize, enablePrefetch: enablePrefetch, routingBias: routingBias)
    }
    
    func handleMemoryWarning() {
        bridge.handleMemoryWarning()
    }
    
    private func startMetricsPolling() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            var m = InferenceMetrics()
            m.tokensPerSecond = self.bridge.tokensPerSecond
            m.timeToFirstToken = self.bridge.timeToFirstToken
            m.promptTokensPerSecond = self.bridge.promptTokensPerSecond
            m.expertCacheHitRate = self.bridge.expertCacheHitRate
            m.storageReadsCount = UInt64(self.bridge.storageReadsCount)
            m.diskThroughput = self.bridge.diskThroughputMBs
            m.loadedExpertCount = Int(self.bridge.loadedExpertCount)
            m.isGenerating = self.bridge.isGenerating
            m.availableProcessMemory = MemoryInfo.currentAvailable
            
            // Map thermal state
            switch ProcessInfo.processInfo.thermalState {
            case .nominal: m.thermalState = .nominal
            case .fair: m.thermalState = .fair
            case .serious: m.thermalState = .serious
            case .critical: m.thermalState = .critical
            @unknown default: m.thermalState = .nominal
            }
            
            DispatchQueue.main.async {
                self.metrics = m
            }
        }
    }
}
