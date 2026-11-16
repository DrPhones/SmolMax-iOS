import SwiftUI
import UniformTypeIdentifiers

struct ModelsView: View {
    @EnvironmentObject var modelManager: ModelManager
    @EnvironmentObject var inferenceManager: InferenceManager
    @ObservedObject var loc = LocalizationManager.shared
    
    @State private var showFileImporter = false
    @State private var showCuratedSheet = false
    @State private var modelToDelete: LLMModel?
    @State private var showDeleteAlert = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Storage Bar
                storageHeader
                
                // Active Download Status (if any)
                if modelManager.downloader.isDownloading {
                    downloadProgressCard
                }
                
                // Models List
                if modelManager.models.isEmpty {
                    emptyModelsView
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(modelManager.models) { model in
                                ModelCardView(
                                    model: model,
                                    isActive: inferenceManager.currentModel?.id == model.id,
                                    compatibility: modelManager.evaluateCompatibility(for: model),
                                    onSelect: {
                                        Task {
                                            await inferenceManager.loadModel(model)
                                        }
                                    },
                                    onDelete: {
                                        modelToDelete = model
                                        showDeleteAlert = true
                                    }
                                )
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle(loc.localized("tab_models"))
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button(action: { showCuratedSheet = true }) {
                        Image(systemName: "arrow.down.circle")
                    }
                    
                    Button(action: { showFileImporter = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [UTType(filenameExtension: "gguf") ?? .data],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let firstUrl = urls.first {
                        Task {
                            await modelManager.importModel(from: firstUrl)
                        }
                    }
                case .failure(let error):
                    print("[ModelsView] File import error: \(error)")
                }
            }
            .sheet(isPresented: $showCuratedSheet) {
                ModelImportSheet()
            }
            .alert("تأكيد الحذف", isPresented: $showDeleteAlert) {
                Button("إلغاء", role: .cancel) {}
                Button("حذف", role: .destructive) {
                    if let target = modelToDelete {
                        Task {
                            await modelManager.deleteModel(id: target.id)
                        }
                    }
                }
            } message: {
                Text("هل أنت متأكد من حذف هذا النموذج؟ سيتم تحرير مساحة التخزين الخاصة به.")
            }
        }
        .environment(\.layoutDirection, loc.layoutDirection)
    }
    
    // MARK: - Subviews
    
    private var storageHeader: some View {
        HStack {
            Image(systemName: "internaldrive")
                .foregroundColor(.secondary)
            
            Text("مساحة التخزين المتوفرة: \(modelManager.freeStorageFormatted)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.tertiarySystemBackground))
    }
    
    private var downloadProgressCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("جاري تنزيل النموذج...")
                    .font(.caption)
                    .fontWeight(.medium)
                Spacer()
                Text(String(format: "%.1f%%", modelManager.downloader.downloadProgress * 100))
                    .font(.caption)
                    .monospacedDigit()
            }
            
            ProgressView(value: modelManager.downloader.downloadProgress)
                .progressViewStyle(LinearProgressViewStyle())
            
            HStack {
                Button("إلغاء") {
                    modelManager.downloader.cancelDownload()
                }
                .font(.caption2)
                .foregroundColor(.red)
                
                Spacer()
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    private var emptyModelsView: some View {
        VStack(spacing: 20) {
            Image(systemName: "square.and.arrow.down")
                .font(.system(size: 56))
                .foregroundColor(.secondary)
            
            Text(loc.localized("no_models_found"))
                .font(.headline)
            
            Text("يمكنك استيراد ملف GGUF من تطبيق Files أو تحميل نموذج موصى به عبر الإنترنت مباشرة.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            HStack(spacing: 16) {
                Button(action: { showFileImporter = true }) {
                    Label(loc.localized("import_model_file"), systemImage: "folder")
                        .font(.subheadline)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                
                Button(action: { showCuratedSheet = true }) {
                    Label(loc.localized("download_curated"), systemImage: "arrow.down")
                        .font(.subheadline)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color(.secondarySystemBackground))
                        .foregroundColor(.primary)
                        .cornerRadius(12)
                }
            }
        }
        .padding(.top, 80)
    }
}
