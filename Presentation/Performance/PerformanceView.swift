import SwiftUI

/// Real-time hardware telemetry and expert paging performance dashboard
struct PerformanceView: View {
    @EnvironmentObject var inferenceManager: InferenceManager
    @ObservedObject var loc = LocalizationManager.shared
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Top Status Banner
                    engineStatusBanner
                    
                    // Core Inference Speed Section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("سرعة الاستدلال (Inference Speed)")
                            .font(.headline)
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            MetricCard(
                                title: loc.localized("tokens_per_sec"),
                                value: String(format: "%.1f", inferenceManager.metrics.tokensPerSecond),
                                subtitle: "توليد الرموز",
                                icon: "bolt.fill",
                                accentColor: .green
                            )
                            
                            MetricCard(
                                title: loc.localized("ttft"),
                                value: String(format: "%.2f s", inferenceManager.metrics.timeToFirstToken),
                                subtitle: "زمن الاستجابة الأولى",
                                icon: "stopwatch.fill",
                                accentColor: .blue
                            )
                            
                            MetricCard(
                                title: loc.localized("prompt_speed"),
                                value: String(format: "%.1f t/s", inferenceManager.metrics.promptTokensPerSecond),
                                subtitle: "معالجة المدخلات",
                                icon: "gauge.with.needle.fill",
                                accentColor: .purple
                            )
                            
                            MetricCard(
                                title: loc.localized("thermal_state"),
                                value: inferenceManager.metrics.thermalState.rawValue,
                                subtitle: "حرارة Apple A15",
                                icon: "thermometer.medium",
                                accentColor: thermalColor(inferenceManager.metrics.thermalState)
                            )
                        }
                    }
                    
                    Divider().padding(.vertical, 4)
                    
                    // Memory & RAM Footprint Section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("إدارة الذاكرة (Memory Management)")
                            .font(.headline)
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            MetricCard(
                                title: loc.localized("ram_available"),
                                value: ByteCountFormatter.string(fromByteCount: Int64(inferenceManager.metrics.availableProcessMemory), countStyle: .memory),
                                subtitle: "os_proc_available_memory()",
                                icon: "memorychip",
                                accentColor: .cyan
                            )
                            
                            MetricCard(
                                title: "حد الذاكرة الفعلي",
                                value: "6.0 GB",
                                subtitle: "iPhone 13 Pro LPDDR4X",
                                icon: "server.rack",
                                accentColor: .indigo
                            )
                        }
                    }
                    
                    Divider().padding(.vertical, 4)
                    
                    // Smolmaxxing Expert Paging Telemetry Section
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("تقنية Expert Paging (MoE Telemetry)")
                                .font(.headline)
                            Spacer()
                            Image(systemName: "cpu.fill")
                                .foregroundColor(.orange)
                        }
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            MetricCard(
                                title: loc.localized("cache_hit_rate"),
                                value: String(format: "%.1f%%", inferenceManager.metrics.expertCacheHitRate),
                                subtitle: "تفادي قراءة القرص",
                                icon: "arrow.triangle.2.circlepath",
                                accentColor: .orange
                            )
                            
                            MetricCard(
                                title: loc.localized("active_experts"),
                                value: "\(inferenceManager.metrics.loadedExpertCount)",
                                subtitle: "في مجمع RAM",
                                icon: "cube.fill",
                                accentColor: .teal
                            )
                            
                            MetricCard(
                                title: loc.localized("paged_reads"),
                                value: "\(inferenceManager.metrics.storageReadsCount)",
                                subtitle: "عمليات pread()",
                                icon: "opticaldiscdrive.fill",
                                accentColor: .pink
                            )
                            
                            MetricCard(
                                title: loc.localized("disk_throughput"),
                                value: String(format: "%.1f MB/s", inferenceManager.metrics.diskThroughput),
                                subtitle: "سرعة قراءة NVMe APFS",
                                icon: "externaldrive.badge.timemachine",
                                accentColor: .mint
                            )
                        }
                    }
                }
                .padding()
            }
            .navigationTitle(loc.localized("tab_performance"))
        }
        .environment(\.layoutDirection, loc.layoutDirection)
    }
    
    private var engineStatusBanner: some View {
        HStack {
            Image(systemName: inferenceManager.isGenerating ? "waveform.path.ecg" : "checkmark.circle")
                .foregroundColor(inferenceManager.isGenerating ? .orange : .green)
            
            Text(inferenceManager.isGenerating ? "الاستدلال قيد التشغيل..." : "المحرك في وضع الاستعداد")
                .font(.subheadline)
                .fontWeight(.medium)
            
            Spacer()
            
            if inferenceManager.isGenerating {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private func thermalColor(_ state: InferenceMetrics.ThermalState) -> Color {
        switch state {
        case .nominal: return .green
        case .fair: return .yellow
        case .serious: return .orange
        case .critical: return .red
        }
    }
}
