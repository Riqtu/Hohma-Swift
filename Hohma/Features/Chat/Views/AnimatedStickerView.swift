//
//  AnimatedStickerView.swift
//  Hohma
//
//  Created by Assistant on 01.12.2025.
//

import SwiftUI
import Inject
import UIKit
import WebKit
import ImageIO

struct AnimatedStickerView: View {
    @ObserveInjection var inject
    let url: URL
    let isAnimated: Bool
    let size: CGSize
    
    init(url: URL, isAnimated: Bool, size: CGSize = CGSize(width: 120, height: 120)) {
        self.url = url
        self.isAnimated = isAnimated
        self.size = size
    }
    
    var body: some View {
        Group {
            if isAnimated {
                // Для анимированных стикеров используем UIImageView через UIViewRepresentable
                AnimatedStickerImageView(url: url, size: size)
                    .frame(width: size.width, height: size.height)
                    .clipped()
            } else {
                // Для статических стикеров используем CachedAsyncImage с кешированием
                CachedAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: size.width, maxHeight: size.height)
                } placeholder: {
                    ProgressView()
                }
                .frame(width: size.width, height: size.height)
            }
        }
        .frame(width: size.width, height: size.height)
        .contentShape(Rectangle()) // Делаем всю область кликабельной
        .clipped() // Обрезаем содержимое по границам
        .enableInjection()
    }
}

// MARK: - Animated Image WebView
private struct AnimatedImageWebView: UIViewRepresentable {
    let url: URL
    let size: CGSize
    @State private var hasLoaded = false
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.scrollView.isScrollEnabled = false
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.isUserInteractionEnabled = false // Отключаем взаимодействие с WebView
        
        // Загружаем контент
        DispatchQueue.main.async {
            loadContent(webView: webView)
        }
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        if !hasLoaded {
            loadContent(webView: webView)
        }
    }
    
    private func loadContent(webView: WKWebView) {
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
                * {
                    margin: 0;
                    padding: 0;
                    box-sizing: border-box;
                }
                html, body {
                    width: 100%;
                    height: 100%;
                    overflow: hidden;
                    background-color: transparent;
                }
                body {
                    display: flex;
                    justify-content: center;
                    align-items: center;
                }
                img {
                    max-width: 100%;
                    max-height: 100%;
                    width: auto;
                    height: auto;
                    object-fit: contain;
                    display: block;
                }
            </style>
        </head>
        <body>
            <img src="\(url.absoluteString)" alt="Sticker" onload="console.log('Image loaded')" onerror="console.log('Image error')">
        </body>
        </html>
        """
        webView.loadHTMLString(html, baseURL: url.deletingLastPathComponent())
        hasLoaded = true
    }
}

// MARK: - Animated Sticker Image View with WebP/GIF Support
private struct AnimatedStickerImageView: UIViewRepresentable {
    let url: URL
    let size: CGSize
    
    func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        containerView.clipsToBounds = true
        containerView.backgroundColor = .clear
        
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.isUserInteractionEnabled = false
        
        containerView.addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        // Устанавливаем constraints для ограничения размера
        NSLayoutConstraint.activate([
            containerView.widthAnchor.constraint(equalToConstant: size.width),
            containerView.heightAnchor.constraint(equalToConstant: size.height),
            imageView.topAnchor.constraint(equalTo: containerView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            imageView.widthAnchor.constraint(lessThanOrEqualToConstant: size.width),
            imageView.heightAnchor.constraint(lessThanOrEqualToConstant: size.height)
        ])
        
        // Загружаем изображение асинхронно
        Task {
            await loadAnimatedImage(into: imageView)
        }
        
        return containerView
    }
    
    func updateUIView(_ containerView: UIView, context: Context) {
        // Обновляем constraints при изменении размера
        containerView.constraints.forEach { constraint in
            if constraint.firstAttribute == .width {
                constraint.constant = size.width
            } else if constraint.firstAttribute == .height {
                constraint.constant = size.height
            }
        }
        
        if let imageView = containerView.subviews.first as? UIImageView {
            imageView.constraints.forEach { constraint in
                if constraint.firstAttribute == .width {
                    constraint.constant = size.width
                } else if constraint.firstAttribute == .height {
                    constraint.constant = size.height
                }
            }
        }
    }
    
    static func dismantleUIView(_ containerView: UIView, coordinator: ()) {
        if let imageView = containerView.subviews.first as? UIImageView {
            imageView.stopAnimating()
            imageView.animationImages = nil
        }
    }
    
    static func dismantleUIView(_ uiView: UIImageView, coordinator: ()) {
        uiView.stopAnimating()
        uiView.animationImages = nil
    }
    
    private func loadAnimatedImage(into imageView: UIImageView) async {
        do {
            // Используем URLRequest с cachePolicy для кеширования
            let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad)
            let (data, _) = try await URLSession.shared.data(for: request)
            
            // Пробуем загрузить через ImageIO для поддержки GIF и WebP
            guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
                // Fallback: пробуем обычный UIImage
                await MainActor.run {
                    if let image = UIImage(data: data) {
                        imageView.image = image
                    } else {
                        // Если UIImage не может загрузить, показываем placeholder
                        imageView.image = UIImage(systemName: "photo")
                    }
                }
                return
            }
            
            let count = CGImageSourceGetCount(source)
            
            if count > 1 {
                // Анимированное изображение
                var images: [UIImage] = []
                var totalDuration: TimeInterval = 0
                
                for i in 0..<count {
                    if let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) {
                        images.append(UIImage(cgImage: cgImage))
                        
                        // Получаем задержку кадра
                        if let properties = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [String: Any] {
                            var delay: TimeInterval = 0.1
                            
                            // Для GIF
                            if let gifProperties = properties[kCGImagePropertyGIFDictionary as String] as? [String: Any],
                               let delayTime = gifProperties[kCGImagePropertyGIFDelayTime as String] as? Double {
                                delay = delayTime
                            }
                            
                            // Для WebP
                            if let webpProperties = properties[kCGImagePropertyWebPDictionary as String] as? [String: Any],
                               let delayTime = webpProperties[kCGImagePropertyWebPDelayTime as String] as? Double {
                                delay = delayTime
                            }
                            
                            totalDuration += delay
                        }
                    }
                }
                
                await MainActor.run {
                    if !images.isEmpty {
                        imageView.animationImages = images
                        imageView.animationDuration = totalDuration > 0 ? totalDuration : 0.1 * Double(count)
                        imageView.animationRepeatCount = 0 // Бесконечная анимация
                        imageView.image = images.first
                        imageView.startAnimating()
                    }
                }
            } else {
                // Статическое изображение
                if let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) {
                    await MainActor.run {
                        imageView.image = UIImage(cgImage: cgImage)
                    }
                }
            }
        } catch {
            AppLogger.shared.error("Failed to load animated sticker", error: error, category: .ui)
        }
    }
}

