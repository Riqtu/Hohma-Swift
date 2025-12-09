import SwiftUI
import Inject
import UIKit

final class MoviePosterCacheService: ObservableObject {
    static let shared = MoviePosterCacheService()

    private var cache: [String: Image] = [:]
    private var loadingStates: [String: Bool] = [:]
    private let queue = DispatchQueue(label: "race.poster.cache", attributes: .concurrent)

    private init() {}

    func cachedImage(for url: String) -> Image? {
        queue.sync { cache[url] }
    }

    func cache(image: Image, for url: String) {
        queue.async(flags: .barrier) {
            self.cache[url] = image
            self.loadingStates[url] = false
        }
    }

    func setLoading(_ isLoading: Bool, for url: String) {
        queue.async(flags: .barrier) {
            self.loadingStates[url] = isLoading
        }
    }

    func isLoading(_ url: String) -> Bool {
        queue.sync { loadingStates[url] ?? false }
    }
}

struct RacePosterView: View {
    @ObserveInjection var inject
    let posterUrl: String
    let title: String?
    let width: CGFloat
    let height: CGFloat
    let showTitle: Bool

    @StateObject private var cacheService = MoviePosterCacheService.shared
    @State private var cachedImage: Image?
    @State private var isLoading = false
    @State private var hasCheckedCache = false

    init(
        posterUrl: String,
        title: String? = nil,
        width: CGFloat = 60,
        height: CGFloat = 90,
        showTitle: Bool = true
    ) {
        self.posterUrl = posterUrl
        self.title = title
        self.width = width
        self.height = height
        self.showTitle = showTitle
    }

    var body: some View {
        VStack(spacing: 6) {
            posterImage
                .frame(width: width, height: height)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.25), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.35), radius: 4, x: 0, y: 3)

            if showTitle, let title = title, !title.isEmpty {
                Text(title)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: width + 12)
            }
        }
        .onAppear {
            checkCache()
        }
        .enableInjection()
    }

    @ViewBuilder
    private var posterImage: some View {
        if let cachedImage = cachedImage {
            cachedImage
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else if isLoading {
            Rectangle()
                .fill(Color.white.opacity(0.2))
                .overlay(
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                )
        } else {
            CachedAsyncImage(url: URL(string: posterUrl)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .onAppear {
                        cacheService.cache(image: image, for: posterUrl)
                        cachedImage = image
                    }
            } placeholder: {
                Rectangle()
                    .fill(Color.white.opacity(0.2))
                    .overlay(
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    )
            }
            .onAppear {
                loadPoster()
            }
        }
    }

    private func loadPoster() {
        guard !posterUrl.isEmpty else { return }
        if let cached = cacheService.cachedImage(for: posterUrl) {
            cachedImage = cached
            return
        }

        if cacheService.isLoading(posterUrl) {
            isLoading = true
            return
        }

        isLoading = true
        cacheService.setLoading(true, for: posterUrl)

        Task {
            guard let url = URL(string: posterUrl) else {
                await MainActor.run {
                    self.isLoading = false
                    self.cacheService.setLoading(false, for: self.posterUrl)
                }
                return
            }
            
            // Используем ImageCacheService для загрузки с кешированием
            if let uiImage = try? await ImageCacheService.shared.loadImage(from: url) {
                let image = Image(uiImage: uiImage)
                await MainActor.run {
                    self.cacheService.cache(image: image, for: self.posterUrl)
                    self.cachedImage = image
                    self.isLoading = false
                    self.cacheService.setLoading(false, for: self.posterUrl)
                }
            } else {
                await MainActor.run {
                    self.isLoading = false
                    self.cacheService.setLoading(false, for: self.posterUrl)
                }
            }
        }
    }

    private func checkCache() {
        guard !hasCheckedCache else { return }
        hasCheckedCache = true

        if let cached = cacheService.cachedImage(for: posterUrl) {
            cachedImage = cached
        } else if !posterUrl.isEmpty {
            loadPoster()
        }
    }
}

