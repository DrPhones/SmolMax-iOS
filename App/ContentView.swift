import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var loc = LocalizationManager.shared
    
    var body: some View {
        TabView(selection: $appState.selectedTab) {
            ChatView()
                .tabItem {
                    Label(loc.localized("tab_chat"), systemImage: "bubble.left.and.bubble.right.fill")
                }
                .tag(AppState.Tab.chat)
            
            ModelsView()
                .tabItem {
                    Label(loc.localized("tab_models"), systemImage: "cylinder.split.1x2.fill")
                }
                .tag(AppState.Tab.models)
            
            PerformanceView()
                .tabItem {
                    Label(loc.localized("tab_performance"), systemImage: "gauge.with.needle.fill")
                }
                .tag(AppState.Tab.performance)
            
            SettingsView()
                .tabItem {
                    Label(loc.localized("tab_settings"), systemImage: "gearshape.fill")
                }
                .tag(AppState.Tab.settings)
        }
        .environment(\.layoutDirection, loc.layoutDirection)
    }
}
