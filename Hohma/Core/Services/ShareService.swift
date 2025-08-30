import Foundation
import UIKit
import UniformTypeIdentifiers

final class ShareService {
    static let shared = ShareService()
    private init() {}

    func shareWheel(wheel: WheelWithRelations) {
        // Получаем домен из Info.plist
        let domain =
            Bundle.main.object(forInfoDictionaryKey: "API_URL") as? String
            ?? "https://hohma.su"

        // Формируем ссылку на колесо
        let wheelURL = "\(domain)/fortune-wheel/\(wheel.id)"

        // Создаем текст для шаринга
        let shareText = "🎡 Крутите колесо '\(wheel.name)' на Hohma!\n\n\(wheelURL)"

        // Создаем URL для шаринга
        guard let url = URL(string: wheelURL) else { return }

        // Создаем активность для шаринга
        let activityVC = UIActivityViewController(
            activityItems: [shareText, url],
            applicationActivities: nil
        )

        // Показываем контроллер шаринга
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let window = windowScene.windows.first
        {
            window.rootViewController?.present(activityVC, animated: true)
        }
    }
}
