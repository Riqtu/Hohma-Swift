import Combine
import Foundation

@MainActor
final class EditWheelFormViewModel: ObservableObject {
    @Published var wheelName: String = ""
    @Published var selectedThemeId: String?
    @Published var isPrivate: Bool = false
    @Published var themes: [WheelTheme] = []
    @Published var isLoadingThemes = false
    @Published var isUpdating = false
    @Published var error: String?
    @Published var isSuccess = false

    private let wheelService = FortuneWheelService.shared
    private let trpcService = TRPCService.shared
    private let wheelId: String

    init(wheel: WheelWithRelations) {
        self.wheelId = wheel.id
        self.wheelName = wheel.name
        self.selectedThemeId = wheel.themeId
        self.isPrivate = wheel.isPrivate
    }

    var canUpdate: Bool {
        !wheelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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

    func updateWheel() async {
        guard canUpdate else { return }

        isUpdating = true
        error = nil

        do {
            let request = WheelUpdateRequest(
                id: wheelId,
                name: wheelName.trimmingCharacters(in: .whitespacesAndNewlines),
                themeId: selectedThemeId,
                status: nil,  // Не изменяем статус при редактировании
                isPrivate: isPrivate
            )

            let updatedWheel = try await wheelService.updateWheel(request)

            // Уведомляем об успешном обновлении
            NotificationCenter.default.post(
                name: .wheelDataUpdated,
                object: updatedWheel
            )

            isSuccess = true
        } catch {
            self.error = error.localizedDescription
        }

        isUpdating = false
    }
}
