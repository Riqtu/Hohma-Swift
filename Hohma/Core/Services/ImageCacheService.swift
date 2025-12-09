//
//  ImageCacheService.swift
//  Hohma
//
//  Единый сервис для кеширования изображений с использованием URLCache и NSCache
//
//  ИСПОЛЬЗОВАНИЕ:
//  - Для загрузки изображений: await ImageCacheService.shared.loadImage(from: url)
//  - В SwiftUI используйте CachedAsyncImage вместо AsyncImage
//  - Кеш работает автоматически: память (NSCache) + диск (URLCache)
//  - Не нужно прописывать кеш в каждом компоненте - все работает глобально
//

import Foundation
import UIKit
import SwiftUI

/// Единый сервис для кеширования изображений
@MainActor
final class ImageCacheService: ObservableObject {
    static let shared = ImageCacheService()
    
    // MARK: - Properties
    
    /// Кеш декодированных UIImage в памяти (быстрый доступ)
    private let memoryCache: NSCache<NSString, UIImage>
    
    /// URLSession с настроенным кешем
    private let urlSession: URLSession
    
    /// Очередь для потокобезопасных операций
    private let cacheQueue = DispatchQueue(label: "image.cache.queue", attributes: .concurrent)
    
    /// Отслеживание загрузок (чтобы не загружать одно изображение дважды)
    private var loadingTasks: [String: Task<UIImage?, Error>] = [:]
    
    // MARK: - Initialization
    
    private init() {
        // Настраиваем NSCache для декодированных изображений
        memoryCache = NSCache<NSString, UIImage>()
        memoryCache.countLimit = 200  // Максимум 200 изображений в памяти
        memoryCache.totalCostLimit = 100 * 1024 * 1024  // 100 MB
        
        // Настраиваем URLSession с кешем
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = URLCache.shared
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.timeoutIntervalForRequest = 30.0
        configuration.timeoutIntervalForResource = 60.0
        
        urlSession = URLSession(configuration: configuration)
        
        print("📦 ImageCacheService: Инициализирован с лимитами - память: 200 изображений/100MB, диск: через URLCache")
    }
    
    // MARK: - Public Methods
    
    /// Загрузить изображение с кешированием
    /// - Parameters:
    ///   - url: URL изображения
    ///   - forceRefresh: Принудительно обновить из сети (игнорировать кеш)
    /// - Returns: UIImage или nil если загрузка не удалась
    func loadImage(from url: URL, forceRefresh: Bool = false) async throws -> UIImage? {
        let cacheKey = url.absoluteString
        
        // Проверяем кеш в памяти
        if !forceRefresh, let cachedImage = memoryCache.object(forKey: cacheKey as NSString) {
            print("✅ ImageCacheService: Изображение найдено в памяти: \(url.lastPathComponent)")
            return cachedImage
        }
        
        // Проверяем, не загружается ли уже это изображение
        if let existingTask = loadingTasks[cacheKey] {
            print("⏳ ImageCacheService: Изображение уже загружается: \(url.lastPathComponent)")
            return try? await existingTask.value
        }
        
        // Создаем новую задачу загрузки
        let task = Task<UIImage?, Error> {
            defer {
                // Удаляем задачу после завершения
                Task { @MainActor in
                    self.loadingTasks.removeValue(forKey: cacheKey)
                }
            }
            
            // Проверяем URLCache (диск + память HTTP кеша)
            if !forceRefresh {
                let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad)
                if let cachedResponse = URLCache.shared.cachedResponse(for: request),
                   let image = UIImage(data: cachedResponse.data) {
                    print("✅ ImageCacheService: Изображение найдено в URLCache: \(url.lastPathComponent)")
                    // Сохраняем в память для быстрого доступа
                    await MainActor.run {
                        self.memoryCache.setObject(image, forKey: cacheKey as NSString)
                    }
                    return image
                }
            }
            
            // Загружаем из сети
            print("📥 ImageCacheService: Загрузка из сети: \(url.lastPathComponent)")
            let request = URLRequest(
                url: url,
                cachePolicy: forceRefresh ? .reloadIgnoringLocalCacheData : .returnCacheDataElseLoad
            )
            
            let (data, response) = try await urlSession.data(for: request)
            
            // Проверяем HTTP статус
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode != 200 {
                throw URLError(.badServerResponse)
            }
            
            guard let image = UIImage(data: data) else {
                throw URLError(.cannotDecodeContentData)
            }
            
            // Сохраняем в URLCache (автоматически через URLSession)
            // Сохраняем декодированное изображение в память
            await MainActor.run {
                self.memoryCache.setObject(image, forKey: cacheKey as NSString, cost: self.imageCost(image))
            }
            
            print("✅ ImageCacheService: Изображение загружено и закешировано: \(url.lastPathComponent)")
            return image
        }
        
        // Сохраняем задачу
        loadingTasks[cacheKey] = task
        
        return try await task.value
    }
    
    /// Загрузить изображение как SwiftUI Image
    func loadImageAsSwiftUIImage(from url: URL, forceRefresh: Bool = false) async -> Image? {
        guard let uiImage = try? await loadImage(from: url, forceRefresh: forceRefresh) else {
            return nil
        }
        return Image(uiImage: uiImage)
    }
    
    /// Получить изображение из кеша (без загрузки)
    func getCachedImage(from url: URL) -> UIImage? {
        let cacheKey = url.absoluteString
        
        // Проверяем память
        if let cached = memoryCache.object(forKey: cacheKey as NSString) {
            return cached
        }
        
        // Проверяем URLCache
        let request = URLRequest(url: url, cachePolicy: .returnCacheDataDontLoad)
        if let cachedResponse = URLCache.shared.cachedResponse(for: request),
           let image = UIImage(data: cachedResponse.data) {
            // Сохраняем в память для следующего раза
            memoryCache.setObject(image, forKey: cacheKey as NSString, cost: imageCost(image))
            return image
        }
        
        return nil
    }
    
    /// Предзагрузка изображений
    func preloadImages(from urls: [URL]) {
        Task {
            await withTaskGroup(of: Void.self) { group in
                for url in urls {
                    group.addTask {
                        _ = try? await self.loadImage(from: url)
                    }
                }
            }
        }
    }
    
    /// Очистить кеш в памяти
    func clearMemoryCache() {
        memoryCache.removeAllObjects()
        loadingTasks.removeAll()
        print("📦 ImageCacheService: Кеш в памяти очищен")
    }
    
    /// Очистить кеш для конкретного URL
    func clearCache(for url: URL) {
        let cacheKey = url.absoluteString
        memoryCache.removeObject(forKey: cacheKey as NSString)
        
        // Очищаем из URLCache
        let request = URLRequest(url: url)
        URLCache.shared.removeCachedResponse(for: request)
        
        print("📦 ImageCacheService: Кеш очищен для: \(url.lastPathComponent)")
    }
    
    /// Очистить весь кеш
    func clearAllCache() {
        clearMemoryCache()
        URLCache.shared.removeAllCachedResponses()
        print("📦 ImageCacheService: Весь кеш очищен")
    }

    /// Оценить "стоимость" изображения для корректной работы totalCostLimit NSCache
    private func imageCost(_ image: UIImage) -> Int {
        if let cgImage = image.cgImage {
            return cgImage.bytesPerRow * cgImage.height
        }
        if let data = image.pngData() {
            return data.count
        }
        // Фолбэк: площадь * 4 байта (RGBA)
        let pixels = Int(image.size.width * image.scale) * Int(image.size.height * image.scale)
        return pixels * 4
    }
}

