import Foundation

/// Represents an LLM model available on the device
struct LLMModel: Identifiable, Codable {
    let id: UUID
    var name: String
    var fileName: String
    var filePath: URL
    var fileSize: UInt64
    var quantization: QuantizationType
    var parameterCount: String // e.g. "7B", "16B"
    var architecture: ModelArchitecture
    var contextLength: Int
    var estimatedMemoryRequired: UInt64
    var isMoE: Bool
    var expertCount: Int?
    var activeExpertsPerToken: Int?
    var importDate: Date
    var lastUsedDate: Date?
    var shardFiles: [URL]?
    
    /// Whether this model likely needs Expert Paging to run on this device
    var needsExpertPaging: Bool {
        guard isMoE else { return false }
        return estimatedMemoryRequired > MemoryInfo.currentAvailable
    }
    
    var formattedFileSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)
    }
    
    var formattedEstimatedMemory: String {
        ByteCountFormatter.string(fromByteCount: Int64(estimatedMemoryRequired), countStyle: .memory)
    }
}

/// Supported quantization types
enum QuantizationType: String, Codable, CaseIterable {
    case f16 = "F16"
    case q8_0 = "Q8_0"
    case q6_k = "Q6_K"
    case q5_k_m = "Q5_K_M"
    case q5_k_s = "Q5_K_S"
    case q4_k_m = "Q4_K_M"
    case q4_k_s = "Q4_K_S"
    case q4_0 = "Q4_0"
    case q3_k_m = "Q3_K_M"
    case q3_k_s = "Q3_K_S"
    case q2_k = "Q2_K"
    case q1_0 = "Q1_0"
    case iq4_xs = "IQ4_XS"
    case iq3_xxs = "IQ3_XXS"
    case iq2_xxs = "IQ2_XXS"
    case iq1_s = "IQ1_S"
    case unknown = "Unknown"
    
    var displayName: String { rawValue }
    
    var bitsPerWeight: Float {
        switch self {
        case .f16: return 16.0
        case .q8_0: return 8.0
        case .q6_k: return 6.5
        case .q5_k_m, .q5_k_s: return 5.5
        case .q4_k_m, .q4_k_s, .q4_0: return 4.5
        case .q3_k_m, .q3_k_s: return 3.5
        case .q2_k: return 2.5
        case .q1_0: return 1.0
        case .iq4_xs: return 4.25
        case .iq3_xxs: return 3.06
        case .iq2_xxs: return 2.06
        case .iq1_s: return 1.56
        case .unknown: return 4.5
        }
    }
}

/// Model architecture types
enum ModelArchitecture: String, Codable {
    case llama
    case qwen2
    case qwen2moe
    case mistral
    case gemma
    case phi
    case deepseek
    case commandr
    case other
    
    var displayName: String {
        switch self {
        case .llama: return "LLaMA"
        case .qwen2: return "Qwen2"
        case .qwen2moe: return "Qwen2-MoE"
        case .mistral: return "Mistral"
        case .gemma: return "Gemma"
        case .phi: return "Phi"
        case .deepseek: return "DeepSeek"
        case .commandr: return "Command-R"
        case .other: return "Other"
        }
    }
}

/// Model compatibility status for the current device
enum ModelCompatibility {
    case compatible
    case requiresExpertPaging
    case marginal(reason: String)
    case incompatible(reason: String)
    case unknown
    
    var displayText: String {
        switch self {
        case .compatible:
            return "Compatible"
        case .requiresExpertPaging:
            return "Requires Expert Paging"
        case .marginal(let reason):
            return "Marginal: \(reason)"
        case .incompatible(let reason):
            return "Incompatible: \(reason)"
        case .unknown:
            return "Unknown"
        }
    }
    
    var isLoadable: Bool {
        switch self {
        case .compatible, .requiresExpertPaging, .marginal:
            return true
        case .incompatible, .unknown:
            return false
        }
    }
}
