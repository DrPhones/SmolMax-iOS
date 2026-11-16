import SwiftUI

/// Curated model download sheet with verified direct download links
struct ModelImportSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var modelManager: ModelManager
    @ObservedObject var loc = LocalizationManager.shared
    
    struct CuratedModel: Identifiable {
        let id = UUID()
        let name: String
        let tier: String
        let size: String
        let quant: String
        let isMoE: Bool
        let url: URL
        let sha256: String?
        let description: String
    }
    
    let curatedList: [CuratedModel] = [
        CuratedModel(
            name: "Qwen2.5-0.5B-Instruct",
            tier: "Stage A — Baseline",
            size: "398 MB",
            quant: "Q4_K_M",
            isMoE: false,
            url: URL(string: "https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf")!,
            sha256: nil,
            description: "Ultra-fast baseline model for instant device verification."
        ),
        CuratedModel(
            name: "Llama-3.2-1B-Instruct",
            tier: "Stage A — Baseline",
            size: "820 MB",
            quant: "Q4_K_M",
            isMoE: false,
            url: URL(string: "https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q4_K_M.gguf")!,
            sha256: nil,
            description: "High quality small dense model from Meta."
        ),
        CuratedModel(
            name: "SmolLM2-1.7B-Instruct",
            tier: "Stage A — Baseline",
            size: "1.1 GB",
            quant: "Q4_K_M",
            isMoE: false,
            url: URL(string: "https://huggingface.co/HuggingFaceTB/SmolLM2-1.7B-Instruct-GGUF/resolve/main/smollm2-1.7b-instruct-q4_k_m.gguf")!,
            sha256: nil,
            description: "Excellent lightweight reasoning model from Hugging Face."
        ),
        CuratedModel(
            name: "Ling-mini-2.0 (16B MoE)",
            tier: "Stage C — Smolmaxxing 16B",
            size: "8.4 GB",
            quant: "Q4_K_M",
            isMoE: true,
            url: URL(string: "https://huggingface.co/bartowski/inclusionAI_Ling-mini-2.0-GGUF/resolve/main/inclusionAI_Ling-mini-2.0-Q4_K_M.gguf")!,
            sha256: nil,
            description: "Smolmaxxing flagship MoE model! 16B parameters, 1.4B active. Requires Expert Paging."
        ),
        CuratedModel(
            name: "Qwen3.6-35B-A3B (Experimental)",
            tier: "Stage D — 35B Experimental",
            size: "12.3 GB",
            quant: "Q3_K_M",
            isMoE: true,
            url: URL(string: "https://huggingface.co/hyperionaidev/Qwen3.6-35B-A3B-phone-GGUF/resolve/main/qwen3.6-35b-a3b-q3_k_m.gguf")!,
            sha256: nil,
            description: "Experimental 35B MoE model. Requires high-speed NVMe expert streaming."
        )
    ]
    
    var body: some View {
        NavigationStack {
            List(curatedList) { item in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(item.name)
                            .font(.headline)
                        Spacer()
                        Text(item.size)
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    }
                    
                    Text(item.tier)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.purple.opacity(0.15))
                        .foregroundColor(.purple)
                        .cornerRadius(4)
                    
                    Text(item.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button(action: {
                        modelManager.downloadCuratedModel(url: item.url, fileName: item.url.lastPathComponent, sha256: item.sha256)
                        dismiss()
                    }) {
                        Label(loc.localized("download_curated"), systemImage: "arrow.down.circle")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .padding(.top, 4)
                }
                .padding(.vertical, 4)
            }
            .navigationTitle(loc.localized("download_curated"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("إغلاق") { dismiss() }
                }
            }
        }
        .environment(\.layoutDirection, loc.layoutDirection)
    }
}
