import SwiftUI

/// Bilingual localization helper supporting both Arabic and English seamlessly
enum Language: String, CaseIterable {
    case arabic = "ar"
    case english = "en"
}

class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()
    
    @AppStorage("selectedLanguage") var currentLanguage: String = "ar"
    
    var isRTL: Bool {
        return currentLanguage == "ar"
    }
    
    var layoutDirection: LayoutDirection {
        return isRTL ? .rightToLeft : .leftToRight
    }
    
    func localized(_ key: String) -> String {
        let isAr = (currentLanguage == "ar")
        switch key {
        case "app_title": return isAr ? "سمول ماكس iOS" : "SmolMax iOS"
        case "tab_chat": return isAr ? "المحادثة" : "Chat"
        case "tab_models": return isAr ? "النماذج" : "Models"
        case "tab_performance": return isAr ? "الأداء" : "Performance"
        case "tab_settings": return isAr ? "الإعدادات" : "Settings"
        
        // Chat
        case "no_model_loaded": return isAr ? "لم يتم تحميل أي نموذج" : "No Model Loaded"
        case "select_model_prompt": return isAr ? "يرجى اختيار أو استيراد نموذج للبدء" : "Please select or import a model to start"
        case "message_placeholder": return isAr ? "اكتب رسالتك هنا..." : "Type your message here..."
        case "stop_generation": return isAr ? "إيقاف التوليد" : "Stop"
        case "regenerate": return isAr ? "إعادة المحاولة" : "Regenerate"
        case "copy": return isAr ? "نسخ" : "Copy"
        case "copied": return isAr ? "تم النسخ!" : "Copied!"
        case "clear_chat": return isAr ? "مسح المحادثة" : "Clear Chat"
        case "loading_model": return isAr ? "جاري تحميل النموذج..." : "Loading model..."
        
        // Models
        case "installed_models": return isAr ? "النماذج المثبتة" : "Installed Models"
        case "no_models_found": return isAr ? "لا توجد نماذج مثبتة حالياً" : "No models found"
        case "import_model_file": return isAr ? "استيراد ملف GGUF من Files" : "Import GGUF from Files"
        case "download_curated": return isAr ? "تحميل نماذج موصى بها" : "Download Curated Models"
        case "active_model": return isAr ? "النموذج النشط" : "Active Model"
        case "activate": return isAr ? "تفعيل" : "Activate"
        case "delete": return isAr ? "حذف" : "Delete"
        case "size": return isAr ? "الحجم" : "Size"
        case "quant": return isAr ? "التكميم" : "Quant"
        case "memory_req": return isAr ? "الذاكرة التقديرية" : "Est. RAM"
        case "expert_paging_required": return isAr ? "يتطلب تقنية Expert Paging" : "Requires Expert Paging"
        
        // Performance
        case "metrics_dashboard": return isAr ? "لوحة مؤشرات الأداء" : "Performance Dashboard"
        case "tokens_per_sec": return isAr ? "الرموز / ثانية" : "Tokens / Sec"
        case "ttft": return isAr ? "زمن أول رمز (TTFT)" : "Time to First Token"
        case "prompt_speed": return isAr ? "معالجة المدخلات" : "Prompt Speed"
        case "ram_available": return isAr ? "الذاكرة المتاحة" : "Available RAM"
        case "cache_hit_rate": return isAr ? "نسبة نجاح التخزين المؤقت" : "Expert Cache Hit Rate"
        case "paged_reads": return isAr ? "قراءات التخزين (pread)" : "Storage Reads"
        case "disk_throughput": return isAr ? "سرعة قراءة القرص" : "Disk Throughput"
        case "thermal_state": return isAr ? "الحالة الحرارية" : "Thermal State"
        case "active_experts": return isAr ? "الخبراء النشطون في RAM" : "Active Experts in RAM"
        
        // Settings
        case "inference_settings": return isAr ? "إعدادات الاستدلال" : "Inference Settings"
        case "safe_mode": return isAr ? "الوضع الآمن (Safe Mode)" : "Safe Mode"
        case "experimental_mode": return isAr ? "الوضع التجريبي (Experimental)" : "Experimental Mode"
        case "cpu_threads": return isAr ? "خيوط المعالج (Threads)" : "CPU Threads"
        case "context_length": return isAr ? "طول السياق (Context)" : "Context Length"
        case "temperature": return isAr ? "درجة الحرارة (Temperature)" : "Temperature"
        case "expert_pool_size": return isAr ? "حجم مجمع الخبراء (Pool Size)" : "Expert Pool Size"
        case "enable_prefetch": return isAr ? "التنبؤ المسبق بالخبراء (Prefetch)" : "Expert Prefetching"
        case "routing_bias": return isAr ? "انحياز التوجيه للذاكرة (Routing Bias)" : "Cache-Aware Routing Bias"
        case "use_metal_gpu": return isAr ? "تسريع Metal GPU (اختياري)" : "Enable Metal GPU"
        case "memory_safety": return isAr ? "حماية الذاكرة الصارمة" : "Strict Memory Safety"
        case "language": return isAr ? "اللغة" : "Language"
        case "about": return isAr ? "حول التطبيق" : "About"
        
        default: return key
        }
    }
}
