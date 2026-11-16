import Foundation
import Combine

/// Monitors device thermal state and provides throttling mitigation hints
class ThermalMonitor: ObservableObject {
    @Published var thermalState: ProcessInfo.ThermalState = .nominal
    
    init() {
        self.thermalState = ProcessInfo.processInfo.thermalState
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(thermalStateDidChange),
            name: ProcessInfo.thermalStateDidChangeNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func thermalStateDidChange(notification: Notification) {
        DispatchQueue.main.async {
            self.thermalState = ProcessInfo.processInfo.thermalState
        }
    }
    
    var isThrottled: Bool {
        return thermalState == .serious || thermalState == .critical
    }
    
    var suggestedThreadCountReduction: Int {
        switch thermalState {
        case .nominal, .fair: return 0
        case .serious: return 1
        case .critical: return 2
        @unknown default: return 0
        }
    }
}
