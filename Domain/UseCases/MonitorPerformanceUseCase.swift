import Foundation

/// Use case for aggregating and analyzing inference performance & hardware health
class MonitorPerformanceUseCase {
    private let engine: InferenceEngineProtocol
    private let memoryManager: MemoryManagerProtocol
    
    init(engine: InferenceEngineProtocol, memoryManager: MemoryManagerProtocol) {
        self.engine = engine
        self.memoryManager = memoryManager
    }
    
    func getCurrentMetrics() -> InferenceMetrics {
        var metrics = engine.metrics
        metrics.availableProcessMemory = memoryManager.availableMemory
        return metrics
    }
    
    func getDeviceStats() -> (physicalRAM: String, freeMemory: String, pressure: String) {
        let physical = ByteCountFormatter.string(fromByteCount: Int64(memoryManager.physicalMemory), countStyle: .memory)
        let free = ByteCountFormatter.string(fromByteCount: Int64(memoryManager.availableMemory), countStyle: .memory)
        let pressure = memoryManager.memoryPressureLevel.rawValue
        return (physical, free, pressure)
    }
}
