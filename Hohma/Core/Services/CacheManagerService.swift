//
//  CacheManagerService.swift
//  Hohma
//
//  Created for cache management
//

import Foundation
import UIKit

@MainActor
class CacheManagerService: ObservableObject {
    static let shared = CacheManagerService()
    
    /// Размеры именно кеша (URLCache, hohma_cache и временные файлы, которые считаем кешем)
    @Published var urlCacheSize: Int64 = 0
    @Published var diskCacheSize: Int64 = 0
    @Published var memoryCacheSize: Int64 = 0
    
    /// Размер пользовательских данных (Documents) — не считаем кэшем, считаем отдельно
    @Published var documentsSize: Int64 = 0
    
    private let userDefaults = UserDefaults.standard
    private let maxURLCacheMemoryKey = "maxURLCacheMemory"
    private let maxURLCacheDiskKey = "maxURLCacheDisk"
    
    // Лимиты по умолчанию (в байтах)
    // Увеличены для приложения с чатом и медиа (фото, видео, стикеры, аватары)
    private let defaultMemoryLimit: Int = 100 * 1024 * 1024  // 100 MB (было 50 MB)
    private let defaultDiskLimit: Int = 500 * 1024 * 1024     // 500 MB (было 200 MB)
    
    private init() {
        setupURLCache()
        updateCacheSizes()
    }
    
    // MARK: - URL Cache Configuration
    
    private func setupURLCache() {
        let memoryCapacity = getMemoryLimit()
        let diskCapacity = getDiskLimit()
        
        let cache = URLCache(
            memoryCapacity: memoryCapacity,
            diskCapacity: diskCapacity,
            diskPath: "hohma_cache"
        )
        URLCache.shared = cache
        
        print("📦 CacheManager: Настроен URLCache - память: \(memoryCapacity / 1024 / 1024) MB, диск: \(diskCapacity / 1024 / 1024) MB")
    }
    
    // MARK: - Cache Limits
    
    func getMemoryLimit() -> Int {
        let saved = userDefaults.integer(forKey: maxURLCacheMemoryKey)
        return saved > 0 ? saved : defaultMemoryLimit
    }
    
    func getDiskLimit() -> Int {
        let saved = userDefaults.integer(forKey: maxURLCacheDiskKey)
        return saved > 0 ? saved : defaultDiskLimit
    }
    
    func setMemoryLimit(_ limit: Int) {
        userDefaults.set(limit, forKey: maxURLCacheMemoryKey)
        userDefaults.synchronize()
        setupURLCache()
        // НЕ обновляем размеры кэша при изменении лимита - размер не меняется
    }
    
    func setDiskLimit(_ limit: Int) {
        userDefaults.set(limit, forKey: maxURLCacheDiskKey)
        userDefaults.synchronize()
        setupURLCache()
        // НЕ обновляем размеры кэша при изменении лимита - размер не меняется
    }

    // Быстро сбрасываем метрики, чтобы UI сразу видел "пусто" после очистки
    private func resetCacheMetrics() {
        urlCacheSize = 0
        diskCacheSize = 0
        memoryCacheSize = 0
    }
    
    // MARK: - Cache Size Calculation
    
    func updateCacheSizes() {
        Task {
            await calculateCacheSizes()
        }
    }
    
    private func calculateCacheSizes() async {
        // Размер дискового кэша (реальный размер занятого места) — считаем только кешевые директории
        diskCacheSize = await calculateDiskCacheSize()
        
        // Размер кэша в памяти (реальный размер, не лимит)
        // URLCache не предоставляет прямой способ узнать реальный размер памяти
        // Используем только дисковый кэш
        memoryCacheSize = 0  // Не показываем размер памяти, так как он неточный
        
        // Размер URL кэша = только реальный размер дискового кэша
        urlCacheSize = diskCacheSize
        
        // Размер пользовательских данных (Documents) считаем отдельно
        documentsSize = await calculateDocumentsSize()
        
        // Проверяем, не превышен ли лимит дискового кэша (без учёта Documents)
        let diskLimit = Int64(getDiskLimit())
        if diskCacheSize > diskLimit {
            print("⚠️ CacheManager: Размер кэша (\(diskCacheSize / 1024 / 1024) MB) превышает лимит (\(diskLimit / 1024 / 1024) MB)")
            // URLCache автоматически удалит старые записи при следующем сохранении
            // Но мы можем принудительно очистить часть кэша, если превышение значительное
            if diskCacheSize > diskLimit * 2 {
                print("⚠️ CacheManager: Превышение лимита более чем в 2 раза, рекомендуется очистка кэша")
            }
        }
    }
    
    private func calculateDiskCacheSize() async -> Int64 {
        return await Task.detached(priority: .utility) { [weak self] in
            guard let self = self else { return Int64(0) }
            var totalSize: Int64 = 0
            let fileManager = FileManager.default
            
            // 1. Проверяем нашу кастомную директорию кэша
            if let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
                let customCachePath = cacheDir.appendingPathComponent("hohma_cache")
                let customSize = await self.calculateDirectorySize(at: customCachePath)
                totalSize += customSize
                print("📦 CacheManager: Размер hohma_cache: \(customSize / 1024 / 1024) MB")
                
                // 2. Проверяем стандартную директорию URLCache (может быть в другом месте)
                // URLCache может хранить данные в разных местах в зависимости от iOS версии
                let urlCachePaths = [
                    cacheDir.appendingPathComponent("com.apple.nsurlsessiond"),
                    cacheDir.appendingPathComponent("URLCache")
                ]
                
                for path in urlCachePaths {
                    let size = await self.calculateDirectorySize(at: path)
                    if size > 0 {
                        print("📦 CacheManager: Размер \(path.lastPathComponent): \(size / 1024 / 1024) MB")
                        totalSize += size
                    }
                }
            }
            
        // 4. Проверяем временную директорию (может быть там временные файлы)
            // ВАЖНО: Временная директория может содержать системные файлы iOS
            // Мы считаем только файлы, которые могут быть связаны с нашим приложением
            let tempDir = fileManager.temporaryDirectory
            let tempSize = await self.calculateTemporaryDirectorySize(at: tempDir)
            if tempSize > 0 {
                print("📦 CacheManager: Размер временных файлов приложения: \(tempSize / 1024 / 1024) MB")
            }
            totalSize += tempSize
            
            print("📦 CacheManager: Общий размер кэша (без Documents): \(totalSize / 1024 / 1024) MB")
            return totalSize
        }.value
    }

    private func calculateDocumentsSize() async -> Int64 {
        return await Task.detached(priority: .utility) {
            let fileManager = FileManager.default
            
            guard let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
                return Int64(0)
            }
            
            let size = await self.calculateDirectorySize(at: documentsDir)
            if size > 0 {
                print("📦 CacheManager: Размер пользовательских данных (Documents): \(size / 1024 / 1024) MB")
            }
            return size
        }.value
    }

    /// Удаляет старые записанные медиа (video_/voice_) из Documents, чтобы не копились
    func clearLegacyRecordedMediaInDocuments() async {
        await Task.detached(priority: .utility) {
            let fileManager = FileManager.default
            guard let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
            
            var deletedCount = 0
            var deletedSize: Int64 = 0
            
            if let contents = try? fileManager.contentsOfDirectory(
                at: documentsDir,
                includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) {
                for url in contents {
                    var isDirectory: ObjCBool = false
                    guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory), !isDirectory.boolValue else {
                        continue
                    }
                    
                    let name = url.lastPathComponent.lowercased()
                    let isLegacyMedia = (name.hasPrefix("video_") && name.hasSuffix(".mp4"))
                        || (name.hasPrefix("voice_") && name.hasSuffix(".m4a"))
                    
                    if isLegacyMedia {
                        if let resourceValues = try? url.resourceValues(forKeys: [.fileSizeKey]),
                           let fileSize = resourceValues.fileSize {
                            deletedSize += Int64(fileSize)
                        }
                        do {
                            try fileManager.removeItem(at: url)
                            deletedCount += 1
                        } catch {
                            print("❌ CacheManager: Ошибка при удалении старого медиа \(name): \(error)")
                        }
                    }
                }
            }
            
            if deletedCount > 0 {
                print("📦 CacheManager: Удалены старые медиа из Documents: \(deletedCount) файлов, освобождено \(deletedSize / 1024 / 1024) MB")
            }
        }.value
    }
    
    private func calculateDirectorySize(at url: URL) async -> Int64 {
        return await Task.detached(priority: .utility) {
            let fileManager = FileManager.default
            
            guard fileManager.fileExists(atPath: url.path) else {
                return Int64(0)
            }
            
            // Рекурсивная функция для расчета размера
            func calculateSizeRecursive(at dirURL: URL) -> Int64 {
                var dirSize: Int64 = 0
                
                guard let contents = try? fileManager.contentsOfDirectory(
                    at: dirURL,
                    includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
                    options: [.skipsHiddenFiles, .skipsPackageDescendants]
                ) else {
                    return 0
                }
                
                for fileURL in contents {
                    var isDirectory: ObjCBool = false
                    if fileManager.fileExists(atPath: fileURL.path, isDirectory: &isDirectory) {
                        if isDirectory.boolValue {
                            // Рекурсивно обрабатываем поддиректории
                            dirSize += calculateSizeRecursive(at: fileURL)
                        } else {
                            // Обычный файл
                            if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                               let fileSize = resourceValues.fileSize {
                                dirSize += Int64(fileSize)
                            }
                        }
                    }
                }
                
                return dirSize
            }
            
            return calculateSizeRecursive(at: url)
        }.value
    }
    
    private func calculateTemporaryDirectorySize(at url: URL) async -> Int64 {
        return await Task.detached(priority: .utility) {
            let fileManager = FileManager.default
            
            guard fileManager.fileExists(atPath: url.path) else {
                return Int64(0)
            }
            
            // Рекурсивная функция для расчета размера только файлов приложения
            func calculateSizeRecursive(at dirURL: URL) -> Int64 {
                var dirSize: Int64 = 0
                
                guard let contents = try? fileManager.contentsOfDirectory(
                    at: dirURL,
                    includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
                    options: [.skipsHiddenFiles, .skipsPackageDescendants]
                ) else {
                    return 0
                }
                
                for fileURL in contents {
                    var isDirectory: ObjCBool = false
                    if fileManager.fileExists(atPath: fileURL.path, isDirectory: &isDirectory) {
                        let fileName = fileURL.lastPathComponent
                        
                        // Считаем только файлы, которые могут быть связаны с нашим приложением
                        let isAppFile = fileName.hasSuffix(".mp4") || fileName.hasSuffix(".mov") || fileName.hasSuffix(".m4v") || 
                            fileName.hasSuffix(".jpg") || fileName.hasSuffix(".jpeg") || fileName.hasSuffix(".png") ||
                            fileName.hasPrefix("video_") || fileName.hasPrefix("audio_") ||
                            fileName.contains("hohma") || fileName.contains("chat") ||
                            fileName.hasSuffix(".tmp") || fileName.hasSuffix(".temp")
                        
                        if isDirectory.boolValue {
                            // Рекурсивно обрабатываем поддиректории
                            dirSize += calculateSizeRecursive(at: fileURL)
                        } else if isAppFile {
                            // Обычный файл приложения
                            if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                               let fileSize = resourceValues.fileSize {
                                dirSize += Int64(fileSize)
                            }
                        }
                    }
                }
                
                return dirSize
            }
            
            return calculateSizeRecursive(at: url)
        }.value
    }
    
    // MARK: - Cache Management
    
    func clearURLCache() {
        Task { @MainActor in
            resetCacheMetrics()
            // Очищаем URLCache через API
            URLCache.shared.removeAllCachedResponses()
            // Удаляем файловые директории кэша
            await deleteCacheFiles()
            // Восстанавливаем URLCache с текущими лимитами, чтобы избежать грязных путей
            setupURLCache()
            // Даем файловой системе применить изменения
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 секунды
            // Обновляем размеры после очистки
            updateCacheSizes()
            print("📦 CacheManager: URL кэш очищен и размеры обновлены")
        }
    }
    
    private func deleteCacheFiles() async {
        return await Task.detached(priority: .utility) {
            let fileManager = FileManager.default
            
            // 1. Очищаем URLCache через API (делаем это первым)
            URLCache.shared.removeAllCachedResponses()
            print("📦 CacheManager: URLCache очищен через API")
            
            // 2. Удаляем нашу кастомную директорию кэша
            if let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
                let customCachePath = cacheDir.appendingPathComponent("hohma_cache")
                if fileManager.fileExists(atPath: customCachePath.path) {
                    do {
                        try fileManager.removeItem(at: customCachePath)
                        print("📦 CacheManager: Кастомная директория кэша удалена")
                    } catch {
                        print("❌ CacheManager: Ошибка при удалении кастомной директории: \(error)")
                    }
                }
                
                // 3. Удаляем стандартные директории URLCache
                let urlCachePaths = [
                    cacheDir.appendingPathComponent("com.apple.nsurlsessiond"),
                    cacheDir.appendingPathComponent("URLCache")
                ]
                
                for path in urlCachePaths {
                    if fileManager.fileExists(atPath: path.path) {
                        do {
                            try fileManager.removeItem(at: path)
                            print("📦 CacheManager: Директория \(path.lastPathComponent) удалена")
                        } catch {
                            print("❌ CacheManager: Ошибка при удалении \(path.lastPathComponent): \(error)")
                        }
                    }
                }
            }
            
            // 4. Очищаем временную директорию (там могут быть временные видео)
            // Это делается отдельной функцией clearTemporaryFiles()
        }.value
    }
    
    func clearAvatarCache() {
        AvatarCacheService.shared.clearCache()
        print("📦 CacheManager: Кэш аватарок очищен")
    }
    
    func clearVideoThumbnailCache() {
        // Кэш превью видео очищается автоматически при очистке памяти
        // или можно добавить прямой доступ через публичный API
        print("📦 CacheManager: Кэш превью видео будет очищен при следующей очистке памяти")
    }
    
    func clearAllCaches() {
        Task { @MainActor in
            resetCacheMetrics()
            // Очищаем все кэши
            URLCache.shared.removeAllCachedResponses()
            clearAvatarCache()
            clearVideoThumbnailCache()
            
            // Удаляем файловые кэши и временные файлы
            await deleteCacheFiles()
            await clearTemporaryFiles()
            await clearLegacyRecordedMediaInDocuments()
            // Восстанавливаем URLCache с текущими лимитами
            setupURLCache()
            // Небольшая задержка перед обновлением размеров
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 секунды
            // Обновляем размеры после очистки
            updateCacheSizes()
            print("📦 CacheManager: Все кэши очищены и размеры обновлены")
        }
    }
    
    func clearTemporaryFiles() async {
        return await Task.detached(priority: .utility) {
            let fileManager = FileManager.default
            let tempDir = fileManager.temporaryDirectory
            
            do {
                let tempContents = try fileManager.contentsOfDirectory(
                    at: tempDir,
                    includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey]
                )
                var deletedCount = 0
                var deletedSize: Int64 = 0
                
                // Рекурсивная функция для удаления файлов и директорий
                func deleteRecursive(at url: URL) -> (count: Int, size: Int64) {
                    var totalCount = 0
                    var totalSize: Int64 = 0
                    
                    var isDirectory: ObjCBool = false
                    guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
                        return (0, 0)
                    }
                    
                    if isDirectory.boolValue {
                        // Это директория - рекурсивно удаляем содержимое
                        if let contents = try? fileManager.contentsOfDirectory(
                            at: url,
                            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey]
                        ) {
                            for itemURL in contents {
                                let (count, size) = deleteRecursive(at: itemURL)
                                totalCount += count
                                totalSize += size
                            }
                        }
                        // Удаляем саму директорию
                        do {
                            try fileManager.removeItem(at: url)
                            totalCount += 1
                        } catch {
                            print("❌ CacheManager: Ошибка при удалении директории \(url.lastPathComponent): \(error)")
                        }
                    } else {
                        // Это файл
                        let fileName = url.lastPathComponent
                        
                        // Удаляем файлы, которые могут быть связаны с нашим приложением
                        let shouldDelete = fileName.hasSuffix(".mp4") || fileName.hasSuffix(".mov") || fileName.hasSuffix(".m4v") || 
                            fileName.hasSuffix(".jpg") || fileName.hasSuffix(".jpeg") || fileName.hasSuffix(".png") ||
                            fileName.hasPrefix("video_") || fileName.hasPrefix("audio_") ||
                            fileName.contains("hohma") || fileName.contains("chat") ||
                            fileName.hasSuffix(".tmp") || fileName.hasSuffix(".temp") ||
                            fileName.hasPrefix("CFNetwork") || fileName.hasPrefix("NSURLSession")
                        
                        if shouldDelete {
                            // Считаем размер перед удалением
                            if let resourceValues = try? url.resourceValues(forKeys: [.fileSizeKey]),
                               let fileSize = resourceValues.fileSize {
                                totalSize += Int64(fileSize)
                            }
                            
                            do {
                                try fileManager.removeItem(at: url)
                                totalCount += 1
                            } catch {
                                print("❌ CacheManager: Ошибка при удалении \(fileName): \(error)")
                            }
                        }
                    }
                    
                    return (totalCount, totalSize)
                }
                
                // Удаляем все файлы и директории во временной директории
                for fileURL in tempContents {
                    let (count, size) = deleteRecursive(at: fileURL)
                    deletedCount += count
                    deletedSize += size
                }
                
                if deletedCount > 0 {
                    print("📦 CacheManager: Удалено временных файлов: \(deletedCount), освобождено: \(deletedSize / 1024 / 1024) MB")
                } else {
                    print("📦 CacheManager: Временные файлы не найдены или не удалены")
                }
            } catch {
                print("❌ CacheManager: Ошибка при очистке временных файлов: \(error)")
            }
        }.value
    }
    
    // MARK: - Format Helpers
    
    func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Video Thumbnail Cache Extension
// Note: VideoThumbnailCache находится в MessageBubbleView.swift как private actor
// Для очистки нужно добавить метод clearCache в сам VideoThumbnailCache

