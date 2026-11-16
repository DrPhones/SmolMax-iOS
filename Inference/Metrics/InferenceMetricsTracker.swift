import Foundation
import Combine

/// Aggregates and tracks real-time and historical performance metrics for benchmarking
class InferenceMetricsTracker: ObservableObject {
    @Published var currentMetrics: InferenceMetrics = InferenceMetrics()
    @Published var generationHistory: [SessionBenchmarkRecord] = []
    
    struct SessionBenchmarkRecord: Identifiable {
        let id = UUID()
        let timestamp = Date()
        let modelName: String
        let promptTokensCount: Int
        let generatedTokensCount: Int
        let tokensPerSecond: Double
        let timeToFirstToken: Double
        let cacheHitRate: Double
        let diskThroughputMBs: Double
        let peakMemoryMB: Double
    }
    
    func recordCompletedSession(
        modelName: String,
        promptTokens: Int,
        generatedTokens: Int,
        tps: Double,
        ttft: Double,
        cacheHitRate: Double,
        diskThroughput: Double,
        peakMemoryMB: Double
    ) {
        let record = SessionBenchmarkRecord(
            modelName: modelName,
            promptTokensCount: promptTokens,
            generatedTokensCount: generatedTokens,
            tokensPerSecond: tps,
            timeToFirstToken: ttft,
            cacheHitRate: cacheHitRate,
            diskThroughputMBs: diskThroughput,
            peakMemoryMB: peakMemoryMB
        )
        generationHistory.append(record)
    }
}
