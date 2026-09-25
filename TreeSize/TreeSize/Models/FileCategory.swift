import SwiftUI

/// Категория файла для цветового кодирования на карте диска (ТЗ 2.1.2)
nonisolated enum FileCategory: String, CaseIterable, Sendable {
    case application
    case media
    case image
    case document
    case archive
    case developer
    case cache
    case other

    var displayName: String {
        switch self {
        case .application: return "Приложения"
        case .media: return "Медиа"
        case .image: return "Изображения"
        case .document: return "Документы"
        case .archive: return "Архивы"
        case .developer: return "Разработка"
        case .cache: return "Кэш"
        case .other: return "Прочее"
        }
    }

    /// Базовый цвет категории в HSB для вариации яркости между соседями
    var baseHue: Double {
        switch self {
        case .application: return 0.58
        case .media: return 0.83
        case .image: return 0.92
        case .document: return 0.12
        case .archive: return 0.07
        case .developer: return 0.45
        case .cache: return 0.0
        case .other: return 0.33
        }
    }

    var baseSaturation: Double {
        switch self {
        case .cache: return 0.0
        default: return 0.62
        }
    }

    /// Цвет с вариацией яркости, чтобы соседние блоки одной категории различались
    func color(variant: Int) -> Color {
        let brightness = [0.78, 0.62, 0.88][variant % 3]
        return Color(hue: baseHue, saturation: baseSaturation, brightness: brightness)
    }

    static func classify(url: URL, isDirectory: Bool) -> FileCategory {
        if isDirectory {
            let path = url.path
            if path.contains("/Library/Caches")
                || path.contains("/DerivedData")
                || path.contains("/ModuleCache.noindex") {
                return .cache
            }
            switch url.pathExtension.lowercased() {
            case "app", "appex", "bundle", "framework", "plugin", "kext", "xpc":
                return .application
            default:
                return .other
            }
        }

        switch url.pathExtension.lowercased() {
        case "mp4", "mov", "avi", "mkv", "m4v", "wmv", "mp3", "wav", "aac",
             "flac", "aiff", "m4a", "ogg", "mid":
            return .media
        case "jpg", "jpeg", "png", "gif", "heic", "heif", "tiff", "webp",
             "bmp", "svg", "raw", "cr2", "nef", "psd", "ai":
            return .image
        case "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "txt", "md",
             "rtf", "pages", "numbers", "key", "csv", "epub":
            return .document
        case "zip", "rar", "7z", "tar", "gz", "bz2", "xz", "dmg", "iso",
             "pkg", "cab", "zst":
            return .archive
        case "swift", "h", "m", "mm", "c", "cpp", "js", "ts", "jsx", "tsx",
             "py", "rb", "go", "rs", "java", "kt", "php", "sh", "xcodeproj",
             "pbxproj", "plist", "gemspec", "json", "yaml", "yml", "toml",
             "lock", "gradle", "jar", "class":
            return .developer
        default:
            return .other
        }
    }
}
