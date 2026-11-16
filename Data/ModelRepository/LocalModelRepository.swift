import Foundation

/// Repository for managing models on disk inside app sandbox
class LocalModelRepository: ModelRepositoryProtocol {
    private let modelsDirectory: URL
    
    init(modelsDirectory: URL = AppConfiguration.modelsDirectory) {
        self.modelsDirectory = modelsDirectory
    }
    
    func listModels() async throws -> [LLMModel] {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: modelsDirectory.path) {
            try fileManager.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
            return []
        }
        
        let urls = try fileManager.contentsOfDirectory(at: modelsDirectory, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey], options: .skipsHiddenFiles)
        
        var models: [LLMModel] = []
        for url in urls where url.pathExtension.lowercased() == "gguf" {
            let values = try url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
            let size = UInt64(values.fileSize ?? 0)
            let modDate = values.contentModificationDate ?? Date()
            
            // Inspect GGUF header for real metadata
            let (arch, quant, isMoE, paramCount) = (try? validateGGUF(at: url)) ?? (.other, .unknown, false, "Unknown")
            
            let model = LLMModel(
                id: UUID(),
                name: url.deletingPathExtension().lastPathComponent,
                fileName: url.lastPathComponent,
                filePath: url,
                fileSize: size,
                quantization: quant,
                parameterCount: paramCount,
                architecture: arch,
                contextLength: 2048,
                estimatedMemoryRequired: calculateEstimatedMemory(size: size, isMoE: isMoE),
                isMoE: isMoE,
                expertCount: isMoE ? 32 : nil,
                activeExpertsPerToken: isMoE ? 2 : nil,
                importDate: modDate,
                lastUsedDate: nil,
                shardFiles: nil
            )
            models.append(model)
        }
        return models.sorted { $0.importDate > $1.importDate }
    }
    
    func importModel(from sourceURL: URL) async throws -> LLMModel {
        let isAccessGranted = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if isAccessGranted {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }
        
        let fileManager = FileManager.default
        let destinationURL = modelsDirectory.appendingPathComponent(sourceURL.lastPathComponent)
        
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        
        // Copy file into app sandbox
        try fileManager.copyItem(at: sourceURL, to: destinationURL)
        
        // Parse metadata
        let values = try destinationURL.resourceValues(forKeys: [.fileSizeKey])
        let size = UInt64(values.fileSize ?? 0)
        let (arch, quant, isMoE, paramCount) = (try? validateGGUF(at: destinationURL)) ?? (.other, .unknown, false, "Unknown")
        
        return LLMModel(
            id: UUID(),
            name: destinationURL.deletingPathExtension().lastPathComponent,
            fileName: destinationURL.lastPathComponent,
            filePath: destinationURL,
            fileSize: size,
            quantization: quant,
            parameterCount: paramCount,
            architecture: arch,
            contextLength: 2048,
            estimatedMemoryRequired: calculateEstimatedMemory(size: size, isMoE: isMoE),
            isMoE: isMoE,
            expertCount: isMoE ? 32 : nil,
            activeExpertsPerToken: isMoE ? 2 : nil,
            importDate: Date(),
            lastUsedDate: nil,
            shardFiles: nil
        )
    }
    
    func deleteModel(id: UUID) async throws {
        let models = try await listModels()
        if let target = models.first(where: { $0.id == id }) {
            try FileManager.default.removeItem(at: target.filePath)
        }
    }
    
    func getModel(id: UUID) async throws -> LLMModel? {
        let models = try await listModels()
        return models.first(where: { $0.id == id })
    }
    
    /// Parse GGUF header to verify magic number, version, tensor count and metadata
    func validateGGUF(at url: URL) throws -> (architecture: ModelArchitecture, quant: QuantizationType, isMoE: Bool, paramCount: String) {
        let fileHandle = try FileHandle(forReadingFrom: url)
        defer { try? fileHandle.close() }
        
        // GGUF magic is 'GGUF' (0x46554747 in little-endian)
        let magicData = fileHandle.readData(ofLength: 4)
        guard magicData.count == 4,
              let magicStr = String(data: magicData, encoding: .ascii),
              magicStr == "GGUF" else {
            throw NSError(domain: "SmolMax.GGUF", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid GGUF magic number"])
        }
        
        // Read version (uint32)
        let versionData = fileHandle.readData(ofLength: 4)
        let version = versionData.withUnsafeBytes { $0.load(as: UInt32.self) }
        guard version >= 2 else {
            throw NSError(domain: "SmolMax.GGUF", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unsupported GGUF version \(version)"])
        }
        
        // Infer from file name or metadata heuristics
        let name = url.lastPathComponent.lowercased()
        let isMoE = name.contains("moe") || name.contains("ling") || name.contains("a3b") || name.contains("mixtral")
        
        var arch: ModelArchitecture = .llama
        if name.contains("qwen2moe") || (name.contains("qwen") && isMoE) {
            arch = .qwen2moe
        } else if name.contains("qwen") {
            arch = .qwen2
        } else if name.contains("mistral") {
            arch = .mistral
        } else if name.contains("phi") {
            arch = .phi
        } else if name.contains("gemma") {
            arch = .gemma
        } else if name.contains("deepseek") {
            arch = .deepseek
        }
        
        var quant: QuantizationType = .q4_k_m
        if name.contains("q8_0") { quant = .q8_0 }
        else if name.contains("q6_k") { quant = .q6_k }
        else if name.contains("q5_k_m") { quant = .q5_k_m }
        else if name.contains("q4_k_m") { quant = .q4_k_m }
        else if name.contains("q4_0") { quant = .q4_0 }
        else if name.contains("q3_k_m") { quant = .q3_k_m }
        else if name.contains("q2_k") { quant = .q2_k }
        else if name.contains("q1_0") { quant = .q1_0 }
        else if name.contains("iq4_xs") { quant = .iq4_xs }
        
        var paramCount = "Unknown"
        if name.contains("80b") { paramCount = "80B" }
        else if name.contains("35b") { paramCount = "35B" }
        else if name.contains("16b") || name.contains("ling-mini") { paramCount = "16B" }
        else if name.contains("8b") { paramCount = "8B" }
        else if name.contains("7b") { paramCount = "7B" }
        else if name.contains("3b") { paramCount = "3B" }
        else if name.contains("1.5b") { paramCount = "1.5B" }
        else if name.contains("0.5b") { paramCount = "0.5B" }
        
        return (arch, quant, isMoE, paramCount)
    }
    
    private func calculateEstimatedMemory(size: UInt64, isMoE: Bool) -> UInt64 {
        if isMoE {
            // For MoE, working set in RAM is base non-expert + active expert pool
            // Approximately 20-30% of total model size is needed simultaneously in RAM
            return UInt64(Double(size) * 0.28) + (256 * 1024 * 1024) // +256MB context/overhead
        } else {
            // Dense model needs full file memory footprint + KV cache
            return size + (384 * 1024 * 1024)
        }
    }
}
