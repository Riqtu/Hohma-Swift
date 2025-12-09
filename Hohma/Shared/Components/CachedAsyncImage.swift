//
//  CachedAsyncImage.swift
//  Hohma
//
//  Обертка над AsyncImage с использованием ImageCacheService
//

import SwiftUI

// Используем отдельное имя для системного AsyncImage, чтобы избежать рекурсии
private typealias SystemAsyncImage = SwiftUI.AsyncImage

/// AsyncImage с кешированием через ImageCacheService
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder
    let phaseContent: ((AsyncImagePhase) -> Content)?
    
    @StateObject private var cacheService = ImageCacheService.shared
    @State private var cachedImage: Image?
    @State private var isLoading = false
    @State private var phase: AsyncImagePhase = .empty
    
    init(
        url: URL?,
        scale: CGFloat = 1.0,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
        self.phaseContent = nil
    }
    
    var body: some View {
        Group {
            if let phaseContent = phaseContent {
                phaseContent(phase)
                    .onAppear { loadPhaseImage() }
            } else {
                if let cachedImage = cachedImage {
                    content(cachedImage)
                } else if isLoading {
                    placeholder()
                } else {
                    SystemAsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            placeholder()
                        case .success(let image):
                            content(image)
                                .onAppear {
                                    // Кешируем успешно загруженное изображение
                                    if let url = url {
                                        Task {
                                            _ = try? await cacheService.loadImage(from: url)
                                        }
                                    }
                                    cachedImage = image
                                    isLoading = false
                                }
                        case .failure:
                            placeholder()
                        @unknown default:
                            placeholder()
                        }
                    }
                    .onAppear {
                        loadImage()
                    }
                }
            }
        }
    }
    
    private func loadImage() {
        guard let url = url, cachedImage == nil, !isLoading else { return }
        
        // Проверяем кеш
        if let uiImage = cacheService.getCachedImage(from: url) {
            cachedImage = Image(uiImage: uiImage)
            return
        }
        
        isLoading = true
        
        // Загружаем через ImageCacheService
        Task {
            if let uiImage = try? await cacheService.loadImage(from: url) {
                await MainActor.run {
                    cachedImage = Image(uiImage: uiImage)
                    isLoading = false
                }
            } else {
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
    
    private func loadPhaseImage() {
        guard let url = url else {
            phase = .empty
            return
        }
        
        // Быстрый ответ из кеша
        if let uiImage = cacheService.getCachedImage(from: url) {
            phase = .success(Image(uiImage: uiImage))
            return
        }
        
        phase = .empty
        
        Task {
            do {
                if let uiImage = try await cacheService.loadImage(from: url) {
                    await MainActor.run {
                        phase = .success(Image(uiImage: uiImage))
                    }
                } else {
                    await MainActor.run {
                        phase = .failure(URLError(.badServerResponse))
                    }
                }
            } catch {
                await MainActor.run {
                    phase = .failure(error)
                }
            }
        }
    }
}

// MARK: - Convenience Initializers

extension CachedAsyncImage where Content == Image, Placeholder == ProgressView<EmptyView, EmptyView> {
    /// Упрощенный инициализатор с дефолтными параметрами
    init(url: URL?) {
        self.url = url
        self.content = { $0 }
        self.placeholder = { ProgressView() }
        self.phaseContent = nil
    }
}

extension CachedAsyncImage where Placeholder == ProgressView<EmptyView, EmptyView> {
    /// Инициализатор с кастомным content и дефолтным placeholder
    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content
    ) {
        self.url = url
        self.content = content
        self.placeholder = { ProgressView() }
        self.phaseContent = nil
    }
}

// MARK: - AsyncImagePhase-style initializer

extension CachedAsyncImage where Placeholder == ProgressView<EmptyView, EmptyView> {
    /// Инициализатор совместимый с AsyncImagePhase-сигнатурой
    init(
        url: URL?,
        scale: CGFloat = 1.0,
        transaction: Transaction = Transaction(),
        @ViewBuilder content: @escaping (AsyncImagePhase) -> Content
    ) {
        self.url = url
        self.content = { _ in fatalError("content not used for phase-based init") }
        self.placeholder = { ProgressView() }
        self.phaseContent = content
    }
}

// Заменяем стандартный AsyncImage на кешируемый по всему приложению
typealias AsyncImage = CachedAsyncImage


