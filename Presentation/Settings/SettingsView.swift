import SwiftUI

/// Settings view providing conservative Safe Mode and high-performance Experimental Mode
struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var inferenceManager: InferenceManager
    @ObservedObject var loc = LocalizationManager.shared
    
    @State private var parameters = InferenceParameters.safe
    @State private var isExperimental = false
    
    var body: some View {
        NavigationStack {
            Form {
                // Mode Toggle Section
                Section(header: Text("نمط التشغيل (Operating Mode)")) {
                    Picker("النمط", selection: $isExperimental) {
                        Text(loc.localized("safe_mode")).tag(false)
                        Text(loc.localized("experimental_mode")).tag(true)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .onChange(of: isExperimental) { val in
                        if val {
                            parameters = InferenceParameters.experimental
                            appState.currentMode = .experimental
                        } else {
                            parameters = InferenceParameters.safe
                            appState.currentMode = .safe
                        }
                        inferenceManager.updateParameters(parameters)
                    }
                    
                    if isExperimental {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("الوضع التجريبي يتيح إعدادات متقدمة للنماذج الضخمة، وقد يؤدي لزيادة استهلاك الذاكرة أو الحرارة.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // CPU & Hardware Section
                Section(header: Text("عتاد Apple A15 Bionic")) {
                    Stepper("خيوط المعالج: \(parameters.cpuThreads)", value: $parameters.cpuThreads, in: 1...6)
                    
                    Picker(loc.localized("context_length"), selection: $parameters.contextLength) {
                        Text("1024").tag(1024)
                        Text("2048 (موصى به)").tag(2048)
                        Text("4096").tag(4096)
                        if isExperimental {
                            Text("8192 (تجريبي)").tag(8192)
                        }
                    }
                    
                    Toggle(loc.localized("use_metal_gpu"), isOn: $parameters.useGPU)
                        .disabled(!isExperimental)
                    
                    Toggle(loc.localized("memory_safety"), isOn: $parameters.memorySafetyMode)
                }
                
                // MoE & Expert Paging Section
                Section(header: Text("إعدادات Expert Paging (لنماذج MoE)")) {
                    Stepper("حجم مجمع الخبراء: \(parameters.expertPoolSize)", value: $parameters.expertPoolSize, in: 2...16)
                    
                    Toggle(loc.localized("enable_prefetch"), isOn: $parameters.enablePrefetch)
                    
                    VStack(alignment: .leading) {
                        HStack {
                            Text(loc.localized("routing_bias"))
                            Spacer()
                            Text(String(format: "%.2f", parameters.routingBias))
                                .monospacedDigit()
                        }
                        Slider(value: $parameters.routingBias, in: 0.0...0.5, step: 0.05)
                            .disabled(!isExperimental)
                        
                        Text("القيمة 0.00 تعني توجيه مطابق دقيق (Exact Routing). القيم الأعلى تعطي أفضلية للخبراء المقيمين في RAM لتقليل قراءة القرص.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Sampling Hyperparameters
                Section(header: Text("معاملات التوليد (Sampling Parameters)")) {
                    VStack(alignment: .leading) {
                        HStack {
                            Text(loc.localized("temperature"))
                            Spacer()
                            Text(String(format: "%.2f", parameters.temperature))
                                .monospacedDigit()
                        }
                        Slider(value: $parameters.temperature, in: 0.1...1.5, step: 0.05)
                    }
                    
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Top-P")
                            Spacer()
                            Text(String(format: "%.2f", parameters.topP))
                                .monospacedDigit()
                        }
                        Slider(value: $parameters.topP, in: 0.1...1.0, step: 0.05)
                    }
                    
                    Stepper("Top-K: \(parameters.topK)", value: $parameters.topK, in: 10...100, step: 5)
                    
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Repeat Penalty")
                            Spacer()
                            Text(String(format: "%.2f", parameters.repeatPenalty))
                                .monospacedDigit()
                        }
                        Slider(value: $parameters.repeatPenalty, in: 1.0...1.5, step: 0.05)
                    }
                }
                
                // Localization & Language
                Section(header: Text(loc.localized("language"))) {
                    Picker("اللغة / Language", selection: $loc.currentLanguage) {
                        Text("العربية (Arabic)").tag("ar")
                        Text("English").tag("en")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                // About
                Section(header: Text(loc.localized("about"))) {
                    HStack {
                        Text("الإصدار")
                        Spacer()
                        Text("1.0.0 (SmolMax)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("محرك الاستدلال")
                        Spacer()
                        Text("llama.cpp v1.0.0 + ExpertPager")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("الجهاز المستهدف")
                        Spacer()
                        Text("iPhone 13 Pro (Apple A15)")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle(loc.localized("tab_settings"))
            .onAppear {
                parameters = inferenceManager.currentParameters
                isExperimental = (appState.currentMode == .experimental)
            }
            .onChange(of: parameters.cpuThreads) { _ in saveParams() }
            .onChange(of: parameters.contextLength) { _ in saveParams() }
            .onChange(of: parameters.temperature) { _ in saveParams() }
            .onChange(of: parameters.topP) { _ in saveParams() }
            .onChange(of: parameters.topK) { _ in saveParams() }
            .onChange(of: parameters.repeatPenalty) { _ in saveParams() }
            .onChange(of: parameters.expertPoolSize) { _ in saveParams() }
            .onChange(of: parameters.enablePrefetch) { _ in saveParams() }
            .onChange(of: parameters.routingBias) { _ in saveParams() }
            .onChange(of: parameters.useGPU) { _ in saveParams() }
            .onChange(of: parameters.memorySafetyMode) { _ in saveParams() }
        }
        .environment(\.layoutDirection, loc.layoutDirection)
    }
    
    private func saveParams() {
        inferenceManager.updateParameters(parameters)
    }
}
