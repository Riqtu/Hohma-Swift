import Combine
import Foundation

@MainActor
final class CreateWheelFormViewModel: ObservableObject {
    @Published var wheelName: String = ""
    @Published var selectedThemeId: String?
    @Published var themes: [WheelTheme] = []
    @Published var isLoadingThemes = false
    @Published var isCreating = false
    @Published var error: String?
    @Published var isSuccess = false

    private let wheelService = FortuneWheelService.shared

    var canCreate: Bool {
        !wheelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedThemeId != nil
    }

    func loadThemes() async {
        isLoadingThemes = true
        error = nil

        do {
            themes = try await wheelService.getAllThemes()
        } catch let networkError as NSError {
            self.error = networkError.localizedDescription
        } catch {
            self.error = "Неизвестная ошибка при загрузке тем"
        }

        isLoadingThemes = false
    }

    func createWheel() async {
        guard canCreate else { return }

        isCreating = true
        error = nil

        do {
            let request = WheelCreateRequest(
                name: wheelName.trimmingCharacters(in: .whitespacesAndNewlines),
                themeId: selectedThemeId!,
                status: .active
            )

            let createdWheel = try await wheelService.createWheel(request)

            // Уведомляем об успешном создании
            NotificationCenter.default.post(
                name: .wheelDataUpdated,
                object: createdWheel
            )

            isSuccess = true
        } catch {
            self.error = error.localizedDescription
        }

        isCreating = false
    }
}
