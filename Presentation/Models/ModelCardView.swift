import SwiftUI

/// Clean card displaying model information, compatibility, and action buttons
struct ModelCardView: View {
    let model: LLMModel
    let isActive: Bool
    let compatibility: ModelCompatibility
    let onSelect: () -> Void
    let onDelete: () -> Void
    
    @ObservedObject var loc = LocalizationManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header: Name & Active Indicator
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.name)
                        .font(.headline)
                        .lineLimit(1)
                    
                    Text("\(model.architecture.displayName) • \(model.parameterCount)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isActive {
                    Label(loc.localized("active_model"), systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            
            // Badges row
            HStack(spacing: 8) {
                badge(text: model.quantization.displayName, color: .purple)
                badge(text: model.formattedFileSize, color: .blue)
                if model.isMoE {
                    badge(text: "MoE (\(model.expertCount ?? 32) Exp)", color: .orange)
                }
            }
            
            // Compatibility Warning or Badge
            HStack(spacing: 6) {
                Image(systemName: compatibilityIcon)
                    .foregroundColor(compatibilityColor)
                    .font(.caption)
                
                Text(compatibility.displayText)
                    .font(.caption2)
                    .foregroundColor(compatibilityColor)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(compatibilityColor.opacity(0.1))
            .cornerRadius(6)
            
            Divider()
            
            // Actions
            HStack {
                Button(action: onDelete) {
                    Label(loc.localized("delete"), systemImage: "trash")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                
                Spacer()
                
                if !isActive {
                    Button(action: onSelect) {
                        Text(loc.localized("activate"))
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .disabled(!compatibility.isLoadable)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isActive ? Color.blue : Color.clear, lineWidth: 2)
        )
    }
    
    private func badge(text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .cornerRadius(6)
    }
    
    private var compatibilityIcon: String {
        switch compatibility {
        case .compatible: return "checkmark.seal.fill"
        case .requiresExpertPaging: return "arrow.triangle.2.circlepath"
        case .marginal: return "exclamationmark.triangle.fill"
        case .incompatible: return "xmark.octagon.fill"
        case .unknown: return "questionmark.circle"
        }
    }
    
    private var compatibilityColor: Color {
        switch compatibility {
        case .compatible: return .green
        case .requiresExpertPaging: return .orange
        case .marginal: return .yellow
        case .incompatible: return .red
        case .unknown: return .gray
        }
    }
}
