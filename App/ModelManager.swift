import Foundation
import Combine

/// High-level model manager coordinating local models, downloads, and storage checks
@MainActor
class ModelManager: ObservableObject {
    @Published var models: [LLMModel] = []
    @Published var isLoading: Bool = false
    @Published var freeStorageBytes: UInt64 = 0
    
    let repository = LocalModelRepository()
    let downloader = ModelDownloader()
    private let memoryManager = MemoryManager()
    private lazy var manageModelsUseCase = ManageModelsUseCase(repository: repository, memoryManager: memoryManager)
    
    var freeStorageFormatted: String {
        ByteCountFormatter.string(fromByteCount: Int64(freeStorageBytes), countStyle: .file)
    }
    
    init() {
        refreshStorageInfo()
        Task {
            await reloadModels()
        }
    }
    
    func reloadModels() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            self.models = try await manageModelsUseCase.listModels()
            refreshStorageInfo()
        } catch {
            print("[ModelManager] Failed to list models: \(error)")
        }
    }
    
    func importModel(from url: URL) async {
        do {
            _ = try await manageModelsUseCase.importModel(from: url)
            await reloadModels()
        } catch {
            print("[ModelManager] Failed to import model: \(error)")
        }
    }
    
    func deleteModel(id: UUID) async {
        do {
            try await manageModelsUseCase.deleteModel(id: id)
            await reloadModels()
        } catch {
            print("[ModelManager] Failed to delete model: \(error)")
        }
    }
    
    func evaluateCompatibility(for model: LLMModel) -> ModelCompatibility {
        return manageModelsUseCase.evaluateCompatibility(for: model)
    }
    
    func downloadCuratedModel(url: URL, fileName: String, sha256: String?) {
        downloader.startDownload(url: url, fileName: fileName, expectedSHA256: sha256) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let downloadedUrl):
                    print("[ModelManager] Successfully downloaded: \(downloadedUrl.lastPathComponent)")
                    Task {
                        await self?.reloadModels()
                    }
                case .failure(let error):
                    print("[ModelManager] Download error: \(error)")
                }
            }
        }
    }
    
    private func refreshStorageInfo() {
        let fileManager = FileManager.default
        let documentDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        if let systemAttributes = try? fileManager.attributesOfFileSystem(forPath: documentDirectory.path),
           let freeSize = systemAttributes[.systemFreeSize] as? NSNumber {
            self.freeStorageBytes = freeSize.uint64Value
        }
    }
}
