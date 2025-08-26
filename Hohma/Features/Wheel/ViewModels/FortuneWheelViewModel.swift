//
//  FortuneWheelViewModel.swift
//  Hohma
//
//  Created by Artem Vydro on 06.08.2025.
//

import AVFoundation
import Combine
import Foundation
import SwiftUI

@MainActor
class FortuneWheelViewModel: ObservableObject {
    @Published var wheelState = WheelState()
    @Published var users: [AuthUser] = []
    @Published var roomUsers: [AuthUser] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var isVideoReady: Bool = false
    @Published var hasError: Bool = false
    @Published var isSocketReady = false
    @Published var successMessage: String?

    // Services
    private var streamPlayer: StreamPlayer?
    private var streamVideoService = StreamVideoService.shared
    private var socketService: SocketIOServiceV2
    private var wheelService = FortuneWheelService.shared
    private var cancellables = Set<AnyCancellable>()

    private let wheelData: WheelWithRelations
    private let currentUser: AuthUser?

    // MARK: - Public Properties

    var wheelId: String {
        return wheelData.id
    }

    var user: AuthUser? {
        return currentUser
    }

    init(wheelData: WheelWithRelations, currentUser: AuthUser?) {
        self.wheelData = wheelData
        self.currentUser = currentUser

        // Инициализируем SocketIOService с правильным URL и токеном
        let socketURL = wheelService.getSocketURL()

        // Получаем токен из UserDefaults
        var authToken: String?
        if let authResultData = UserDefaults.standard.data(forKey: "authResult"),
            let savedAuthResult = try? JSONDecoder().decode(AuthResult.self, from: authResultData)
        {
            authToken = savedAuthResult.token
        }

        self.socketService = SocketIOServiceV2(baseURL: socketURL, authToken: authToken)

        setupWheel()
        setupSocket()
    }

    private func setupWheel() {
        // Устанавливаем сектора из данных колеса
        wheelState.setSectors(wheelData.sectors)

        // Устанавливаем тему
        if let theme = wheelData.theme {
            wheelState.accentColor = theme.accentColor
            wheelState.mainColor = theme.mainColor
            wheelState.font = theme.font
            wheelState.backVideo = theme.backgroundVideoURL
        }

        // Настраиваем колбэки
        wheelState.setEliminated = { [weak self] sectorId in
            self?.handleSectorEliminated(sectorId)
        }

        wheelState.setWinner = { [weak self] sectorId in
            self?.handleSectorWinner(sectorId)
        }

        wheelState.setWheelStatus = { [weak self] status, wheelId in
            self?.handleWheelStatusChange(status, wheelId: wheelId)
        }

        wheelState.payoutBets = { [weak self] wheelId, winningSectorId in
            self?.handlePayoutBets(wheelId: wheelId, winningSectorId: winningSectorId)
        }
    }

    private func setupSocket() {
        // Подписываемся на изменения состояния сокета
        socketService.$isConnected
            .sink { [weak self] isConnected in
                self?.isSocketReady = isConnected
                if isConnected {
                    // Добавляем небольшую задержку для стабилизации соединения
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self?.joinRoom()
                    }
                }
            }
            .store(in: &cancellables)

        socketService.$error
            .sink { [weak self] error in
                if let error = error {
                    print("❌ FortuneWheelViewModel: Socket error: \(error)")
                    self?.error = error
                }
            }
            .store(in: &cancellables)

        // Настраиваем сокет для wheelState
        wheelState.setupSocket(socketService, roomId: wheelData.id)

        // Подписываемся на обновления пользователей комнаты
        NotificationCenter.default.addObserver(
            forName: .roomUsersUpdated,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            print("👥 FortuneWheelViewModel: Received roomUsersUpdated notification")
            if let users = notification.object as? [AuthUser] {
                print("👥 FortuneWheelViewModel: Updating room users: \(users.count)")
                Task { @MainActor in
                    self?.updateRoomUsers(users)
                }
            } else {
                print("❌ FortuneWheelViewModel: Failed to cast notification object to [AuthUser]")
                print("❌ FortuneWheelViewModel: Object type: \(type(of: notification.object))")
            }
        }

        // Запускаем периодическую проверку здоровья сокета
        startSocketHealthMonitoring()

        // Подключаемся к сокету
        socketService.connect()
    }

    private func startSocketHealthMonitoring() {
        // Проверяем здоровье сокета каждые 30 секунд
        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkSocketHealth()
            }
        }
        print("🏥 FortuneWheelViewModel: Socket health monitoring started")
    }

    private func joinRoom() {
        wheelState.joinRoom(wheelData.id, userId: currentUser)

        // Инициализируем список пользователей с текущим пользователем
        if let currentUser = currentUser {
            updateRoomUsers([currentUser])
            print("👥 FortuneWheelViewModel: Initialized room users with current user")
        }
    }

    func setupVideoBackground() {
        guard let videoURL = URL(string: wheelState.backVideo) else { return }

        // Используем новый StreamVideoService
        streamPlayer = streamVideoService.getStreamPlayer(for: videoURL)

        // Подписываемся на изменения состояния
        streamPlayer?.$isReady
            .sink { [weak self] isReady in
                DispatchQueue.main.async {
                    self?.isVideoReady = isReady
                }
            }
            .store(in: &cancellables)

        streamPlayer?.$isLoading
            .sink { [weak self] isLoading in
                DispatchQueue.main.async {
                    self?.isLoading = isLoading
                }
            }
            .store(in: &cancellables)

        streamPlayer?.$hasError
            .sink { [weak self] hasError in
                DispatchQueue.main.async {
                    self?.hasError = hasError
                }
            }
            .store(in: &cancellables)
    }

    func pauseVideo() {
        streamPlayer?.pause()
    }

    func resumeVideo() {
        streamPlayer?.resume()
    }

    func calculateWheelSize(for geometry: GeometryProxy, availableWidth: CGFloat? = nil) -> CGFloat
    {
        _ = min(geometry.size.width, geometry.size.height)
        _ = max(geometry.size.width, geometry.size.height)

        // Определяем ориентацию
        let isLandscape = geometry.size.width > geometry.size.height

        if isLandscape {
            // В альбомной ориентации используем доступную ширину или высоту
            let availableSpace = availableWidth ?? geometry.size.width
            let wheelSize = min(geometry.size.height * 0.9, availableSpace * 0.7)
            return max(250, min(wheelSize, 700))
        } else {
            // В портретной ориентации используем ширину как основу
            let wheelSize = geometry.size.width * 0.8  // 70% от ширины
            return max(250, min(wheelSize, 500))  // Минимум 250, максимум 500
        }
    }

    // MARK: - Callbacks

    private func handleSectorEliminated(_ sectorId: String) {
        Task {
            do {
                let updatedSector = try await wheelService.updateSector(sectorId, eliminated: true)
                wheelState.updateSector(updatedSector)
            } catch URLError.userAuthenticationRequired {
                // 401 ошибка - пользователь будет автоматически перенаправлен на экран авторизации
                print("🔐 FortuneWheelViewModel: Authorization required for sector update")
            } catch let decodingError as DecodingError {
                self.error =
                    "Ошибка декодирования ответа сервера: \(decodingError.localizedDescription)"
                print("❌ FortuneWheelViewModel: Decoding error for sector update: \(decodingError)")
            } catch {
                self.error = "Ошибка обновления сектора: \(error.localizedDescription)"
                print("❌ FortuneWheelViewModel: Sector update error: \(error)")
            }
        }
    }

    private func handleSectorWinner(_ sectorId: String) {
        Task {
            do {
                let updatedSector = try await wheelService.updateSector(
                    sectorId, eliminated: false, winner: true)
                wheelState.updateSector(updatedSector)
            } catch URLError.userAuthenticationRequired {
                // 401 ошибка - пользователь будет автоматически перенаправлен на экран авторизации
                print("🔐 FortuneWheelViewModel: Authorization required for winner update")
            } catch let decodingError as DecodingError {
                self.error =
                    "Ошибка декодирования ответа сервера: \(decodingError.localizedDescription)"
                print("❌ FortuneWheelViewModel: Decoding error for winner update: \(decodingError)")
            } catch {
                self.error = "Ошибка обновления победителя: \(error.localizedDescription)"
                print("❌ FortuneWheelViewModel: Winner update error: \(error)")
            }
        }
    }

    private func handleWheelStatusChange(_ status: WheelStatus, wheelId: String) {
        Task {
            do {
                let updatedWheel = try await wheelService.updateWheelStatus(wheelId, status: status)
                print("Статус колеса обновлен: \(String(describing: updatedWheel.status))")
            } catch URLError.userAuthenticationRequired {
                // 401 ошибка - пользователь будет автоматически перенаправлен на экран авторизации
                print("🔐 FortuneWheelViewModel: Authorization required for wheel status update")
            } catch let decodingError as DecodingError {
                self.error =
                    "Ошибка декодирования ответа сервера: \(decodingError.localizedDescription)"
                print(
                    "❌ FortuneWheelViewModel: Decoding error for wheel status update: \(decodingError)"
                )
            } catch {
                self.error = "Ошибка обновления статуса колеса: \(error.localizedDescription)"
                print("❌ FortuneWheelViewModel: Wheel status update error: \(error)")
            }
        }
    }

    private func handlePayoutBets(wheelId: String, winningSectorId: String) {
        Task {
            do {
                try await wheelService.payoutBets(
                    wheelId: wheelId, winningSectorId: winningSectorId)
                print("Ставки выплачены для сектора: \(winningSectorId)")
            } catch URLError.userAuthenticationRequired {
                // 401 ошибка - пользователь будет автоматически перенаправлен на экран авторизации
                print("🔐 FortuneWheelViewModel: Authorization required for payout")
            } catch let decodingError as DecodingError {
                self.error =
                    "Ошибка декодирования ответа сервера: \(decodingError.localizedDescription)"
                print("❌ FortuneWheelViewModel: Decoding error for payout: \(decodingError)")
            } catch {
                self.error = "Ошибка выплаты ставок: \(error.localizedDescription)"
                print("❌ FortuneWheelViewModel: Payout error: \(error)")
            }
        }
    }

    // MARK: - User Management

    func addUser(_ user: AuthUser) {
        if !users.contains(where: { $0.id == user.id }) {
            users.append(user)
        }
    }

    func removeUser(_ userId: String) {
        users.removeAll { $0.id == userId }
    }

    func updateUsers(_ newUsers: [AuthUser]) {
        users = newUsers
    }

    // MARK: - Game State

    var hasWinner: Bool {
        wheelState.losers.count > 0 && wheelState.sectors.count == 1
    }

    var winnerUser: AuthUser? {
        wheelState.sectors.first?.user
    }

    var currentUserCoins: Int {
        currentUser?.coins ?? 0
    }

    var isGameActive: Bool {
        wheelState.sectors.count > 1
    }

    var canSpin: Bool {
        !wheelState.spinning && isGameActive && isSocketReady && socketService.isConnected
    }

    // MARK: - Socket Management

    func reconnectSocket() {
        print("🔄 FortuneWheelViewModel: Manually reconnecting socket")
        socketService.forceReconnect()
    }

    func checkSocketHealth() {
        print("🔍 FortuneWheelViewModel: Socket health check")
        print("   - Connected: \(socketService.isConnected)")
        print("   - Connecting: \(socketService.isConnecting)")
        print("   - Error: \(socketService.error ?? "none")")
        print("   - Connection state valid: \(socketService.validateConnectionState())")

        // Если сокет помечен как подключенный, но состояние невалидно, принудительно переподключаемся
        if socketService.isConnected && !socketService.validateConnectionState() {
            print(
                "⚠️ FortuneWheelViewModel: Socket marked as connected but state is invalid, forcing reconnect"
            )
            reconnectSocket()
        }
    }

    // MARK: - Room Users Management

    private func updateRoomUsers(_ users: [AuthUser]) {
        DispatchQueue.main.async {
            print(
                "👥 FortuneWheelViewModel: Updating roomUsers array from \(self.roomUsers.count) to \(users.count)"
            )
            self.roomUsers = users
            print("👥 FortuneWheelViewModel: Room users updated: \(users.count) users")

            // Выводим имена пользователей для отладки
            for (index, user) in users.enumerated() {
                print(
                    "👥 FortuneWheelViewModel: User \(index + 1): \(String(describing: user.username)) (\(user.firstName ?? "no name"))"
                )
            }
        }
    }

    // MARK: - Sector Management

    func addSector(_ sector: Sector) {
        Task {
            do {
                let createdSector = try await wheelService.createSector(sector)

                // Отправляем сокет событие
                let sectorData = try JSONEncoder().encode(createdSector)
                if let sectorDict = try JSONSerialization.jsonObject(with: sectorData)
                    as? [String: Any]
                {
                    socketService.emitToRoom(.sectorCreated, roomId: wheelData.id, data: sectorDict)
                }

                // Обновляем состояние колеса
                wheelState.addSector(createdSector)

            } catch URLError.userAuthenticationRequired {
                print("🔐 FortuneWheelViewModel: Authorization required for sector creation")
            } catch let decodingError as DecodingError {
                self.error =
                    "Ошибка декодирования ответа сервера: \(decodingError.localizedDescription)"
                print(
                    "❌ FortuneWheelViewModel: Decoding error for sector creation: \(decodingError)")
            } catch {
                self.error = "Ошибка создания сектора: \(error.localizedDescription)"
                print("❌ FortuneWheelViewModel: Sector creation error: \(error)")
            }
        }
    }

    func deleteSector(_ sector: Sector) {
        // Проверяем, что текущий пользователь является владельцем сектора
        guard let currentUser = currentUser,
            sector.userId == currentUser.id
        else {
            self.error = "Вы можете удалять только свои секторы"
            return
        }

        Task {
            do {
                _ = try await wheelService.deleteSector(sector.id)

                // Отправляем сокет событие
                socketService.emitToRoom(.sectorRemoved, roomId: wheelData.id, data: sector.id)

                // Обновляем состояние колеса
                wheelState.removeSector(id: sector.id)

                // Показываем уведомление об успехе
                self.successMessage = "Сектор успешно удален"

            } catch URLError.userAuthenticationRequired {
                print("🔐 FortuneWheelViewModel: Authorization required for sector deletion")
            } catch let decodingError as DecodingError {
                self.error =
                    "Ошибка декодирования ответа сервера: \(decodingError.localizedDescription)"
                print(
                    "❌ FortuneWheelViewModel: Decoding error for sector deletion: \(decodingError)")
            } catch {
                self.error = "Ошибка удаления сектора: \(error.localizedDescription)"
                print("❌ FortuneWheelViewModel: Sector deletion error: \(error)")
            }
        }
    }

    // MARK: - Cleanup

    func cleanup() {
        wheelState.cleanup()
        socketService.disconnect()
        cancellables.removeAll()

        // Отписываемся от уведомлений
        NotificationCenter.default.removeObserver(
            self, name: .roomUsersUpdated, object: nil)
    }
}
