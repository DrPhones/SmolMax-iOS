import SwiftUI

@main
struct SmolMaxApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var inferenceManager = InferenceManager()
    @StateObject private var modelManager = ModelManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(inferenceManager)
                .environmentObject(modelManager)
                .onAppear {
                    appState.initialize()
                }
        }
    }
}
