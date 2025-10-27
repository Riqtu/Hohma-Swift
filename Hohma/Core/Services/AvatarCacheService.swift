import Foundation
import SwiftUI
import Inject

/// Сервис для кэширования аватарок пользователей
class AvatarCacheService: ObservableObject {
    static let shared = AvatarCacheService()

    private var imageCache: [String: Image] = [:]
    private var loadingStates: [String: Bool] = [:]
    private let cacheQueue = DispatchQueue(label: "avatar.cache", attributes: .concurrent)

    private init() {}

    /// Получить кэшированное изображение аватара
    func getCachedImage(for userId: String, avatarUrl: String?) -> Image? {
        guard let avatarUrl = avatarUrl, !avatarUrl.isEmpty else { return nil }
        let cacheKey = "\(userId)_\(avatarUrl)"

        return cacheQueue.sync {
            return imageCache[cacheKey]
        }
    }

    /// Проверить, загружается ли изображение
    func isLoading(for userId: String, avatarUrl: String?) -> Bool {
        guard let avatarUrl = avatarUrl, !avatarUrl.isEmpty else { return false }
        let cacheKey = "\(userId)_\(avatarUrl)"

        return cacheQueue.sync {
            return loadingStates[cacheKey] ?? false
        }
    }

    /// Кэшировать изображение
    func cacheImage(_ image: Image, for userId: String, avatarUrl: String) {
        let cacheKey = "\(userId)_\(avatarUrl)"

        cacheQueue.async(flags: .barrier) {
            self.imageCache[cacheKey] = image
            self.loadingStates[cacheKey] = false
        }
    }

    /// Установить состояние загрузки
    func setLoading(_ isLoading: Bool, for userId: String, avatarUrl: String) {
        let cacheKey = "\(userId)_\(avatarUrl)"

        cacheQueue.async(flags: .barrier) {
            self.loadingStates[cacheKey] = isLoading
        }
    }

    /// Очистить кэш
    func clearCache() {
        cacheQueue.async(flags: .barrier) {
            self.imageCache.removeAll()
            self.loadingStates.removeAll()
        }
    }

    /// Очистить кэш для конкретного пользователя
    func clearCache(for userId: String) {
        cacheQueue.async(flags: .barrier) {
            let keysToRemove = self.imageCache.keys.filter { $0.hasPrefix("\(userId)_") }
            keysToRemove.forEach { key in
                self.imageCache.removeValue(forKey: key)
                self.loadingStates.removeValue(forKey: key)
            }
        }
    }

    /// Предзагрузка аватарок для участников скачки
    func preloadAvatars(for participants: [RaceParticipant]) {
        for participant in participants {
            guard let avatarUrl = participant.user.avatarUrl, !avatarUrl.isEmpty else { continue }
            let cacheKey = "\(participant.user.id)_\(avatarUrl)"

            // Проверяем, не загружено ли уже изображение
            if imageCache[cacheKey] == nil && !(loadingStates[cacheKey] ?? false) {
                loadingStates[cacheKey] = true

                // Загружаем изображение в фоне
                DispatchQueue.global(qos: .userInitiated).async {
                    if let url = URL(string: avatarUrl),
                        let data = try? Data(contentsOf: url),
                        let uiImage = UIImage(data: data)
                    {
                        let image = Image(uiImage: uiImage)

                        DispatchQueue.main.async {
                            self.cacheImage(image, for: participant.user.id, avatarUrl: avatarUrl)
                        }
                    } else {
                        DispatchQueue.main.async {
                            self.setLoading(false, for: participant.user.id, avatarUrl: avatarUrl)
                        }
                    }
                }
            }
        }
    }
}

/// Оптимизированный компонент для отображения аватарок с кэшированием
struct CachedAvatarView: View {
    @ObserveInjection var inject
    let userId: String
    let avatarUrl: String?
    let size: CGFloat
    let fallbackColor: Color
    let showBorder: Bool
    let borderColor: Color

    @StateObject private var cacheService = AvatarCacheService.shared
    @State private var cachedImage: Image?
    @State private var isLoading: Bool = false
    @State private var hasCheckedCache: Bool = false

    init(
        userId: String,
        avatarUrl: String?,
        size: CGFloat = 40,
        fallbackColor: Color = .gray,
        showBorder: Bool = true,
        borderColor: Color = .white
    ) {
        self.userId = userId
        self.avatarUrl = avatarUrl
        self.size = size
        self.fallbackColor = fallbackColor
        self.showBorder = showBorder
        self.borderColor = borderColor
    }

    var body: some View {
        Group {
            if let cachedImage = cachedImage {
                // Показываем кэшированное изображение
                cachedImage
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(borderColor, lineWidth: showBorder ? 1 : 0)
                    )
            } else if isLoading {
                // Показываем fallback вместо индикатора загрузки для лучшего UX
                fallbackView
            } else {
                // Показываем fallback и загружаем изображение
                AsyncImage(url: URL(string: avatarUrl ?? "")) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: size, height: size)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(borderColor, lineWidth: showBorder ? 1 : 0)
                            )
                            .onAppear {
                                // Кэшируем успешно загруженное изображение
                                cacheService.cacheImage(
                                    image, for: userId, avatarUrl: avatarUrl ?? "")
                                cachedImage = image
                                isLoading = false
                            }
                    case .failure, .empty:
                        fallbackView
                    @unknown default:
                        fallbackView
                    }
                }
                .onAppear {
                    checkCache()
                }
            }
        }
    }

    private var fallbackView: some View {
        Image(systemName: "person.circle.fill")
            .resizable()
            .foregroundColor(fallbackColor)
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(borderColor, lineWidth: showBorder ? 1 : 0)
            )
    }

    private func checkCache() {
        guard !hasCheckedCache else { return }
        hasCheckedCache = true

        if let cached = cacheService.getCachedImage(for: userId, avatarUrl: avatarUrl) {
            cachedImage = cached
        } else if let avatarUrl = avatarUrl, !avatarUrl.isEmpty {
            isLoading = true
            cacheService.setLoading(true, for: userId, avatarUrl: avatarUrl)
        }
    }
}

/// Специальный компонент для аватарок в скачках с максимальной оптимизацией
struct RaceAvatarView: View {
    @ObserveInjection var inject
    let participant: RaceParticipant
    let size: CGFloat
    let showBorder: Bool
    let borderColor: Color

    @StateObject private var cacheService = AvatarCacheService.shared
    @State private var cachedImage: Image?
    @State private var hasCheckedCache: Bool = false

    init(
        participant: RaceParticipant,
        size: CGFloat = 56,
        showBorder: Bool = true,
        borderColor: Color = .white
    ) {
        self.participant = participant
        self.size = size
        self.showBorder = showBorder
        self.borderColor = borderColor
    }

    var body: some View {
        Group {
            if let cachedImage = cachedImage {
                // Показываем кэшированное изображение
                cachedImage
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(borderColor, lineWidth: showBorder ? 1 : 0)
                    )
            } else {
                // Показываем fallback и загружаем изображение
                AsyncImage(url: URL(string: participant.user.avatarUrl ?? "")) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: size, height: size)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(borderColor, lineWidth: showBorder ? 1 : 0)
                            )
                            .onAppear {
                                // Кэшируем успешно загруженное изображение
                                cacheService.cacheImage(
                                    image, for: participant.user.id,
                                    avatarUrl: participant.user.avatarUrl ?? "")
                                cachedImage = image
                            }
                    case .failure, .empty:
                        initialsView
                    @unknown default:
                        initialsView
                    }
                }
                .onAppear {
                    checkCache()
                }
            }
        }
    }

    private var initialsView: some View {
        ZStack {
            Circle()
                .fill(.gray.opacity(0.3))
                .frame(width: size, height: size)

            Text(participantInitials)
                .font(.system(size: size * 0.3, weight: .bold))
                .foregroundColor(.white)
        }
    }

    private var participantInitials: String {
        let name = participant.user.name ?? participant.user.username ?? "U"
        let components = name.components(separatedBy: " ")

        if components.count >= 2 {
            let firstInitial = String(components[0].prefix(1)).uppercased()
            let secondInitial = String(components[1].prefix(1)).uppercased()
            return firstInitial + secondInitial
        } else {
            return String(name.prefix(2)).uppercased()
        }
    }

    private func checkCache() {
        guard !hasCheckedCache else { return }
        hasCheckedCache = true

        if let cached = cacheService.getCachedImage(
            for: participant.user.id, avatarUrl: participant.user.avatarUrl)
        {
            cachedImage = cached
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        CachedAvatarView(
            userId: "test1",
            avatarUrl: nil,
            size: 80,
            fallbackColor: .yellow
        )
        CachedAvatarView(
            userId: "test2",
            avatarUrl: "https://example.com/avatar.jpg",
            size: 40,
            fallbackColor: .gray
        )
    }
}
