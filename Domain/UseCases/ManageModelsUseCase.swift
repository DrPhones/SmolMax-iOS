import Foundation

/// Use case for listing, importing, validating, and deleting local models
class ManageModelsUseCase {
    private let repository: ModelRepositoryProtocol
    private let memoryManager: MemoryManagerProtocol
    
    init(repository: ModelRepositoryProtocol, memoryManager: MemoryManagerProtocol) {
        self.repository = repository
        self.memoryManager = memoryManager
    }
    
    func listModels() async throws -> [LLMModel] {
        return try await repository.listModels()
    }
    
    func importModel(from url: URL) async throws -> LLMModel {
        // Validate sufficient storage space before copying
        let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey])
        guard let fileSize = resourceValues.fileSize else {
            throw NSError(domain: "SmolMax.Import", code: 400, userInfo: [NSLocalizedDescriptionKey: "Cannot read file size"])
        }
        
        // Verify free storage
        let fileManager = FileManager.default
        let documentDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let systemAttributes = try fileManager.attributesOfFileSystem(forPath: documentDirectory.path)
        if let freeSize = systemAttributes[.systemFreeSize] as? NSNumber {
            if freeSize.uint64Value < UInt64(fileSize) + AppConfiguration.minimumFreeStorage {
                throw NSError(domain: "SmolMax.Import", code: 507, userInfo: [NSLocalizedDescriptionKey: "Insufficient storage space on device"])
            }
        }
        
        return try await repository.importModel(from: url)
    }
    
    func deleteModel(id: UUID) async throws {
        try await repository.deleteModel(id: id)
    }
    
    func evaluateCompatibility(for model: LLMModel) -> ModelCompatibility {
        let availableMem = memoryManager.availableMemory
        
        if model.isMoE {
            // For MoE, non-expert weights + pool of experts must fit into RAM
            // Non-expert is typically ~1GB, expert pool is typically ~1-2GB
            let estimatedActiveWorkingSet = UInt64(2.5 * 1024 * 1024 * 1024) // ~2.5 GB
            if availableMem > estimatedActiveWorkingSet {
                return .requiresExpertPaging
            } else if availableMem > UInt64(1.5 * 1024 * 1024 * 1024) {
                return .marginal(reason: "Tight RAM. Reduce expert pool size in settings.")
            } else {
                return .incompatible(reason: "Insufficient RAM even with Expert Paging.")
            }
        } else {
            // Dense models must fit entirely in RAM (with mmap headroom)
            if model.fileSize < availableMem {
                return .compatible
            } else if model.fileSize < memoryManager.physicalMemory {
                return .marginal(reason: "Model relies heavily on OS paging; may encounter memory pressure.")
            } else {
                return .incompatible(reason: "Model size (\(model.formattedFileSize)) exceeds device RAM limit.")
            }
        }
    }
}
