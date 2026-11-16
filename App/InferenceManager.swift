import Foundation
import Combine

/// High-level inference manager coordinating LlamaContext, MemoryManager, and UI states
@MainActor
class InferenceManager: ObservableObject {
    @Published var isModelLoaded: Bool = false
    @Published var isGenerating: Bool = false
    @Published var currentModel: LLMModel?
    @Published var currentParameters: InferenceParameters = .safe
    @Published var metrics: InferenceMetrics = InferenceMetrics()
    @Published var errorMessage: String?
    
    private let context = LlamaContext()
    private let memoryManager = MemoryManager()
    private var cancellables = Set<AnyCancellable>()
    
    var currentModelName: String? {
        return currentModel?.name
    }
    
    init() {
        // Bind metrics from context
        context.$metrics
            .receive(on: DispatchQueue.main)
            .sink { [weak self] m in
                self?.metrics = m
                self?.isGenerating = m.isGenerating
            }
            .store(in: &cancellables)
        
        context.$isModelLoaded
            .receive(on: DispatchQueue.main)
            .assign(to: &$isModelLoaded)
        
        // Listen to emergency memory warnings
        memoryManager.registerMemoryPressureHandler { [weak self] level in
            if level == .critical {
                print("[InferenceManager] Critical memory pressure! Clearing caches and pausing generation.")
                self?.context.handleMemoryWarning()
            }
        }
    }
    
    func loadModel(_ model: LLMModel) async {
        do {
            self.errorMessage = nil
            // Check memory safety before loading
            guard memoryManager.canLoadModel(fileSize: model.fileSize, isMoE: model.isMoE, expertPoolSize: currentParameters.expertPoolSize) || !currentParameters.memorySafetyMode else {
                self.errorMessage = "Memory budget exceeded for \(model.name). Safe mode prevented load."
                return
            }
            
            try await context.loadModel(at: model.filePath, parameters: currentParameters)
            self.currentModel = model
        } catch {
            self.errorMessage = "Failed to load model: \(error.localizedDescription)"
        }
    }
    
    func unloadModel() async {
        await context.unloadModel()
        self.currentModel = nil
    }
    
    func generateResponse(conversation: ChatConversation, onToken: @escaping (String) -> Void) async {
        guard isModelLoaded else { return }
        
        let useCase = GenerateChatResponseUseCase(engine: context, memoryManager: memoryManager)
        let stream = useCase.execute(conversation: conversation, parameters: currentParameters)
        
        do {
            for try await token in stream {
                onToken(token)
            }
        } catch {
            print("[InferenceManager] Generation error: \(error)")
        }
    }
    
    func stop() {
        context.stopGeneration()
    }
    
    func updateParameters(_ params: InferenceParameters) {
        self.currentParameters = params
        context.configureExpertPaging(
            poolSize: params.expertPoolSize,
            enablePrefetch: params.enablePrefetch,
            routingBias: params.routingBias
        )
    }
}
