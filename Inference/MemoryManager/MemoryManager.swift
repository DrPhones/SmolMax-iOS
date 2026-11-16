import Foundation
import Combine

/// Comprehensive device memory and safety coordinator
class MemoryManager: ObservableObject, MemoryManagerProtocol {
    @Published var availableMemory: UInt64 = 0
    @Published var memoryPressureLevel: MemoryPressureLevel = .normal
    
    private var memorySource: DispatchSourceMemoryPressure?
    private var pressureHandlers: [(MemoryPressureLevel) -> Void] = []
    private var timer: Timer?
    
    var physicalMemory: UInt64 {
        return ProcessInfo.processInfo.physicalMemory
    }
    
    var safeMemoryBudget: UInt64 {
        return MemoryInfo.safeBudget
    }
    
    init() {
        updateMemory()
        setupMemoryPressureMonitoring()
        startPeriodicUpdate()
    }
    
    deinit {
        memorySource?.cancel()
        timer?.invalidate()
    }
    
    func canLoadModel(fileSize: UInt64, isMoE: Bool, expertPoolSize: Int) -> Bool {
        let budget = safeMemoryBudget
        if isMoE {
            // For MoE: base weights (~20-25% of file) + expert pool (e.g. poolSize * 16MB) + 300MB KV
            let baseWeights = UInt64(Double(fileSize) * 0.25)
            let expertCacheBytes = UInt64(expertPoolSize * 16 * 1024 * 1024)
            let kvAndOverhead = UInt64(300 * 1024 * 1024)
            let totalNeeded = baseWeights + expertCacheBytes + kvAndOverhead
            return totalNeeded < budget
        } else {
            // Dense models need full file in memory (via mmap) + KV cache
            let totalNeeded = fileSize + UInt64(350 * 1024 * 1024)
            return totalNeeded < budget
        }
    }
    
    func registerMemoryPressureHandler(_ handler: @escaping (MemoryPressureLevel) -> Void) {
        pressureHandlers.append(handler)
    }
    
    func requestEmergencyMemoryRelease() {
        print("[MemoryManager] Emergency memory release requested")
        for handler in pressureHandlers {
            handler(.critical)
        }
    }
    
    private func updateMemory() {
        self.availableMemory = MemoryInfo.currentAvailable
    }
    
    private func setupMemoryPressureMonitoring() {
        let source = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical], queue: DispatchQueue.main)
        
        source.setEventHandler { [weak self] in
            guard let self = self else { return }
            let event = source.data
            
            if event.contains(.critical) {
                self.memoryPressureLevel = .critical
                print("[MemoryManager] ⚠️ CRITICAL memory pressure detected!")
                self.notifyHandlers(level: .critical)
            } else if event.contains(.warning) {
                self.memoryPressureLevel = .warning
                print("[MemoryManager] ⚠️ Warning memory pressure detected")
                self.notifyHandlers(level: .warning)
            } else {
                self.memoryPressureLevel = .normal
            }
        }
        
        source.resume()
        self.memorySource = source
    }
    
    private func notifyHandlers(level: MemoryPressureLevel) {
        for handler in pressureHandlers {
            handler(level)
        }
    }
    
    private func startPeriodicUpdate() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateMemory()
        }
    }
}
