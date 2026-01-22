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

    var isSocketConnected: Bool {
        return socketService.isConnected
    }

    func connectSocket() {
        socketService.connect()
    }

    func rejoinRoom() {
        AppLogger.shared.debug("Rejoining room on view appear", category: .ui)

        // Проверяем подключение сокета
        if !socketService.isConnected {
            AppLogger.shared.warning("Socket not connected, connecting...", category: .ui)
            socketService.connect()
        }

        // Настраиваем сокет в wheelState если он не настроен
        if wheelState.socket == nil {
            AppLogger.shared.debug("🔧 FortuneWheelViewModel: Setting up socket in wheelState", category: .ui)
            wheelState.setupSocket(socketService, roomId: wheelData.id)
        }

        // Присоединяемся к комнате
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 секунды
            self.joinRoom()
        }
    }

    init(wheelData: WheelWithRelations, currentUser: AuthUser?) {
        self.wheelData = wheelData
        self.currentUser = currentUser

        // Инициализируем SocketIOService с правильным URL и токеном
        let socketURL = wheelService.getSocketURL()

        // Получаем токен из Keychain
        let authToken = KeychainService.shared.authToken

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

        // Настраиваем видео фон если есть
        if !wheelState.backVideo.isEmpty {
            setupVideoBackground()
        }
    }

    private func setupSocket() {
        AppLogger.shared.debug("🔧 FortuneWheelViewModel: Setting up socket...", category: .ui)
        AppLogger.shared.debug("- socketService.isConnected: \(socketService.isConnected)", category: .ui)

        // Подписываемся на изменения состояния сокета
        socketService.$isConnected
            .sink { [weak self] isConnected in
                AppLogger.shared.debug("🔧 FortuneWheelViewModel: Socket connection state changed: \(isConnected)", category: .ui)
                self?.isSocketReady = isConnected
                if isConnected {
                    // Сбрасываем флаг авторизации при успешном подключении
                    self?.wheelState.resetAuthorization()

                    // Настраиваем сокет в wheelState если он еще не настроен
                    if self?.wheelState.socket == nil {
                        AppLogger.shared.debug("🔧 FortuneWheelViewModel: Setting up socket in wheelState", category: .ui)
                        self?.wheelState.setupSocket(
                            self?.socketService ?? SocketIOServiceV2(),
                            roomId: self?.wheelData.id ?? "")
                    }

                    // Добавляем небольшую задержку для стабилизации соединения
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 секунды
                        self?.joinRoom()
                    }
                }
            }
            .store(in: &cancellables)

        socketService.$error
            .sink { [weak self] error in
                if let error = error {
                    AppLogger.shared.error("Socket error: \(error)", category: .ui)
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
            AppLogger.shared.debug("👥 FortuneWheelViewModel: Received roomUsersUpdated notification", category: .ui)
            if let users = notification.object as? [AuthUser] {
                AppLogger.shared.debug("👥 FortuneWheelViewModel: Updating room users: \(users.count)", category: .ui)
                Task { @MainActor in
                    self?.updateRoomUsers(users)
                }
            } else {
                AppLogger.shared.error("Failed to cast notification object to [AuthUser]", category: .ui)
                AppLogger.shared.error("Object type: \(type(of: notification.object))", category: .ui)
            }
        }

        // Запускаем периодическую проверку здоровья сокета
        startSocketHealthMonitoring()

        // Подключаемся к сокету
        socketService.connect()
    }

    private func startSocketHealthMonitoring() {
        // Проверяем здоровье сокета каждые 30 секунд
        Timer.scheduledTimer(withTimeInterval: AppConstants.wheelUpdateInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkSocketHealth()
            }
        }

        // Обновляем данные колеса каждые 60 секунд для поддержания актуальности
        Timer.scheduledTimer(withTimeInterval: AppConstants.wheelStateUpdateInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refreshWheelDataSilently()
            }
        }

        AppLogger.shared.debug("🏥 FortuneWheelViewModel: Socket health monitoring started", category: .ui)
        AppLogger.shared.debug("Wheel data auto-refresh started (every 60 seconds)", category: .ui)
    }

    private func joinRoom() {
        AppLogger.shared.debug("Joining room: \(wheelData.id)", category: .ui)
        AppLogger.shared.debug("- socketService.isConnected: \(socketService.isConnected)", category: .ui)
        AppLogger.shared.debug("- wheelState.socket exists: \(wheelState.socket != nil)", category: .ui)
        wheelState.joinRoom(wheelData.id, userId: currentUser)

        // Инициализируем список пользователей с текущим пользователем
        if let currentUser = currentUser {
            updateRoomUsers([currentUser])
            AppLogger.shared.debug(
                "FortuneWheelViewModel: Initialized room users with current user: \(String(describing: currentUser.username))", category: .ui)
        }

        // Обновляем данные колеса при подключении к комнате
        Task {
            AppLogger.shared.debug("Refreshing wheel data after joining room", category: .ui)
            await refreshWheelDataSilently()
        }
    }

    func setupVideoBackground() {
        guard let videoURL = URL(string: wheelState.backVideo) else { return }

        // Используем новый StreamVideoService
        streamPlayer = streamVideoService.getStreamPlayer(for: videoURL)

        // Подписываемся на изменения состояния
        streamPlayer?.$isReady
            .sink { [weak self] isReady in
                self?.isVideoReady = isReady
            }
            .store(in: &cancellables)

        streamPlayer?.$isLoading
            .sink { [weak self] isLoading in
                self?.isLoading = isLoading
            }
            .store(in: &cancellables)

        streamPlayer?.$hasError
            .sink { [weak self] hasError in
                self?.hasError = hasError
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
        let minDimension = min(geometry.size.width, geometry.size.height)
        _ = max(geometry.size.width, geometry.size.height)

        // Определяем ориентацию
        let isLandscape = geometry.size.width > geometry.size.height

        // Определяем тип устройства
        _ = UIDevice.current.userInterfaceIdiom == .pad
        let isSmallScreen = minDimension < 600  // Маленький экран (iPad mini, iPhone)

        if isLandscape {
            // В альбомной ориентации используем доступную ширину или высоту
            let availableSpace = availableWidth ?? geometry.size.width
            let wheelSize: CGFloat

            if isSmallScreen {
                // Для маленьких экранов используем более консервативный размер
                wheelSize = min(geometry.size.height * 0.7, availableSpace * 0.5)
            } else {
                wheelSize = min(geometry.size.height * 0.9, availableSpace * 0.7)
            }

            return max(200, min(wheelSize, isSmallScreen ? 400 : 700))
        } else {
            // В портретной ориентации используем ширину как основу
            let wheelSize: CGFloat

            if isSmallScreen {
                // Для маленьких экранов используем более консервативный размер
                wheelSize = geometry.size.width * 0.8  // 60% от ширины для маленьких экранов
            } else {
                wheelSize = geometry.size.width * 0.8  // 80% от ширины для больших экранов
            }

            return max(200, min(wheelSize, isSmallScreen ? 350 : 500))
        }
    }

    // MARK: - Callbacks

    private func handleSectorEliminated(_ sectorId: String) {
        Task {
            do {
                let updatedSector = try await wheelService.updateSector(sectorId, eliminated: true)
                AppLogger.shared.debug(
                    "FortuneWheelViewModel: Sector eliminated successfully: \(updatedSector.name)", category: .ui)

                // Обновляем данные с сервера
                wheelState.requestSectors()
                AppLogger.shared.info("Wheel state updated from server", category: .ui)

            } catch URLError.userAuthenticationRequired {
                // 401 ошибка - пользователь будет автоматически перенаправлен на экран авторизации
                AppLogger.shared.debug("Authorization required for sector update", category: .ui)
            } catch let decodingError as DecodingError {
                self.error =
                    "Ошибка декодирования ответа сервера: \(decodingError.localizedDescription)"
                AppLogger.shared.error("Decoding error for sector update: \(decodingError)", category: .ui)
            } catch {
                self.error = "Ошибка обновления сектора: \(error.localizedDescription)"
                AppLogger.shared.error("Sector update error: \(error)", category: .ui)
            }
        }
    }

    private func handleSectorWinner(_ sectorId: String) {
        Task {
            do {
                let updatedSector = try await wheelService.updateSector(
                    sectorId, eliminated: false, winner: true)
                AppLogger.shared.debug(
                    "FortuneWheelViewModel: Sector winner set successfully: \(updatedSector.name)", category: .ui)

                // Обновляем данные с сервера
                wheelState.requestSectors()
                AppLogger.shared.info("Wheel state updated from server", category: .ui)

            } catch URLError.userAuthenticationRequired {
                // 401 ошибка - пользователь будет автоматически перенаправлен на экран авторизации
                AppLogger.shared.debug("Authorization required for winner update", category: .ui)
            } catch let decodingError as DecodingError {
                self.error =
                    "Ошибка декодирования ответа сервера: \(decodingError.localizedDescription)"
                AppLogger.shared.error("Decoding error for winner update: \(decodingError)", category: .ui)
            } catch {
                self.error = "Ошибка обновления победителя: \(error.localizedDescription)"
                AppLogger.shared.error("Winner update error: \(error)", category: .ui)
            }
        }
    }

    private func handleWheelStatusChange(_ status: WheelStatus, wheelId: String) {
        Task {
            do {
                let updatedWheel = try await wheelService.updateWheelStatus(wheelId, status: status)
                AppLogger.shared.debug("Статус колеса обновлен: \(String(describing: updatedWheel.status))", category: .ui)
            } catch URLError.userAuthenticationRequired {
                // 401 ошибка - пользователь будет автоматически перенаправлен на экран авторизации
                AppLogger.shared.debug("Authorization required for wheel status update", category: .ui)
            } catch let decodingError as DecodingError {
                self.error =
                    "Ошибка декодирования ответа сервера: \(decodingError.localizedDescription)"
                AppLogger.shared.error(
                    "FortuneWheelViewModel: Decoding error for wheel status update", error: decodingError, category: .ui)
            } catch {
                self.error = "Ошибка обновления статуса колеса: \(error.localizedDescription)"
                AppLogger.shared.error("Wheel status update error: \(error)", category: .ui)
            }
        }
    }

    private func handlePayoutBets(wheelId: String, winningSectorId: String) {
        Task {
            do {
                try await wheelService.payoutBets(
                    wheelId: wheelId, winningSectorId: winningSectorId)
                AppLogger.shared.debug("Ставки выплачены для сектора: \(winningSectorId)", category: .ui)
            } catch URLError.userAuthenticationRequired {
                // 401 ошибка - пользователь будет автоматически перенаправлен на экран авторизации
                AppLogger.shared.debug("Authorization required for payout", category: .ui)
            } catch let decodingError as DecodingError {
                self.error =
                    "Ошибка декодирования ответа сервера: \(decodingError.localizedDescription)"
                AppLogger.shared.error("Decoding error for payout: \(decodingError)", category: .ui)
            } catch {
                self.error = "Ошибка выплаты ставок: \(error.localizedDescription)"
                AppLogger.shared.error("Payout error: \(error)", category: .ui)
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
        AppLogger.shared.debug("Manually reconnecting socket", category: .ui)
        socketService.forceReconnect()
    }

    func checkSocketHealth() {
        AppLogger.shared.debug("Socket health check", category: .ui)
        AppLogger.shared.debug("- Connected: \(socketService.isConnected)", category: .ui)
        AppLogger.shared.debug("- Connecting: \(socketService.isConnecting)", category: .ui)
        AppLogger.shared.error("- Error: \(socketService.error ?? "none")", category: .ui)
        AppLogger.shared.debug("- Connection state valid: \(socketService.validateConnectionState())", category: .ui)

        // Если сокет помечен как подключенный, но состояние невалидно, принудительно переподключаемся
        if socketService.isConnected && !socketService.validateConnectionState() {
            AppLogger.shared.warning(
                "FortuneWheelViewModel: Socket marked as connected but state is invalid, forcing reconnect", category: .socket)
            reconnectSocket()
        }
    }

    // MARK: - Room Users Management

    private func updateRoomUsers(_ users: [AuthUser]) {
        AppLogger.shared.debug(
            "FortuneWheelViewModel: Updating roomUsers array from \(self.roomUsers.count) to \(users.count)", category: .ui)
            self.roomUsers = users
            AppLogger.shared.debug("👥 FortuneWheelViewModel: Room users updated: \(users.count) users", category: .ui)

            // Выводим имена пользователей для отладки
            for (index, user) in users.enumerated() {
                AppLogger.shared.debug(
                    "FortuneWheelViewModel: User \(index + 1): \(String(describing: user.username)) (\(user.firstName ?? "no name"))", category: .ui)
            }
        self.roomUsers = users
    }

    // MARK: - Sector Management

    func addSector(_ sector: Sector) {
        Task {
            do {
                AppLogger.shared.debug("Creating sector: \(sector.name)", category: .ui)
                let createdSector = try await wheelService.createSector(sector)
                AppLogger.shared.info("Sector created successfully: \(createdSector.name)", category: .ui)

                // Запрашиваем актуальные данные с сервера
                AppLogger.shared.debug("Refreshing sectors from server...", category: .ui)
                let updatedSectors = try await wheelService.getSectorsByWheelId(wheelData.id)
                AppLogger.shared.debug(
                    "FortuneWheelViewModel: Received \(updatedSectors.count) sectors from server", category: .ui)

                // Находим созданный сектор с полными данными
                if let sectorWithFullData = updatedSectors.first(where: {
                    $0.id == createdSector.id
                }) {
                    // Обновляем состояние колеса актуальными данными
                    wheelState.setSectors(updatedSectors)
                    AppLogger.shared.info("Wheel state updated with fresh data", category: .ui)

                    // Отправляем событие в том же формате, что и веб-клиент
                    let sectorData = try JSONEncoder().encode(sectorWithFullData)
                    if let sectorDict = try JSONSerialization.jsonObject(with: sectorData)
                        as? [String: Any]
                    {
                        AppLogger.shared.debug(
                            "FortuneWheelViewModel: Emitting sector:created event to room \(wheelData.id)", category: .socket)
                        socketService.emitToRoom(
                            .sectorCreated, roomId: wheelData.id, data: sectorDict)
                    }
                } else {
                    AppLogger.shared.warning("Created sector not found in updated data", category: .ui)
                    wheelState.setSectors(updatedSectors)
                }

            } catch URLError.userAuthenticationRequired {
                AppLogger.shared.debug("Authorization required for sector creation", category: .ui)
            } catch let decodingError as DecodingError {
                self.error =
                    "Ошибка декодирования ответа сервера: \(decodingError.localizedDescription)"
                AppLogger.shared.error(
                    "FortuneWheelViewModel: Decoding error for sector creation", error: decodingError, category: .ui)
            } catch {
                self.error = "Ошибка создания сектора: \(error.localizedDescription)"
                AppLogger.shared.error("Sector creation error: \(error)", category: .ui)
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

        // Проверяем подключение сокета

        if !socketService.isConnected {
            AppLogger.shared.warning("Socket not connected, attempting to connect...", category: .ui)
            socketService.connect()

            // Ждем подключения (уменьшили задержку)
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 секунды
                if self.socketService.isConnected {
                    AppLogger.shared.info("Socket connected, proceeding with deletion", category: .ui)
                    self.performSectorDeletion(sector)
                } else {
                    AppLogger.shared.error("Socket still not connected after retry", category: .ui)
                    self.error = "Не удается подключиться к серверу. Попробуйте еще раз."
                }
            }
            return
        }

        // Проверяем, что wheelState настроен с сокетом
        if wheelState.socket == nil {
            AppLogger.shared.warning("wheelState not configured with socket, setting up...", category: .ui)
            wheelState.setupSocket(socketService, roomId: wheelData.id)
        }

        performSectorDeletion(sector)
    }

    private func performSectorDeletion(_ sector: Sector) {

        Task {
            do {
                _ = try await wheelService.deleteSector(sector.id)
                AppLogger.shared.info("Sector deleted successfully: \(sector.name)", category: .ui)

                // Запрашиваем актуальные данные с сервера
                AppLogger.shared.debug("Refreshing sectors from server...", category: .ui)
                let updatedSectors = try await wheelService.getSectorsByWheelId(wheelData.id)
                AppLogger.shared.debug(
                    "FortuneWheelViewModel: Received \(updatedSectors.count) sectors from server", category: .ui)

                // Обновляем состояние колеса актуальными данными
                wheelState.setSectors(updatedSectors)
                AppLogger.shared.info("Wheel state updated with fresh data", category: .ui)

                // Отправляем событие в том же формате, что и веб-клиент
                AppLogger.shared.debug(
                    "FortuneWheelViewModel: Emitting sector:removed event to room \(wheelData.id)", category: .socket)
                socketService.emitToRoom(.sectorRemoved, roomId: wheelData.id, data: sector.id)

                // Показываем уведомление об успехе
                self.successMessage = "Сектор успешно удален"

            } catch URLError.userAuthenticationRequired {
                AppLogger.shared.debug("Authorization required for sector deletion", category: .ui)
            } catch let decodingError as DecodingError {
                self.error =
                    "Ошибка декодирования ответа сервера: \(decodingError.localizedDescription)"
                AppLogger.shared.error(
                    "FortuneWheelViewModel: Decoding error for sector deletion", error: decodingError, category: .ui)
            } catch {
                self.error = "Ошибка удаления сектора: \(error.localizedDescription)"
                AppLogger.shared.error("Sector deletion error: \(error)", category: .ui)
            }
        }
    }

    // MARK: - Wheel Data Refresh

    func refreshWheelData() {
        Task {
            do {
                AppLogger.shared.debug("Refreshing wheel data for ID: \(wheelData.id)", category: .ui)
                let updatedWheelData = try await wheelService.getWheelById(wheelData.id)

                // Обновляем секторы
                wheelState.setSectors(updatedWheelData.sectors)

                // Обновляем тему если она изменилась
                if let theme = updatedWheelData.theme {
                    wheelState.accentColor = theme.accentColor
                    wheelState.mainColor = theme.mainColor
                    wheelState.font = theme.font
                    wheelState.backVideo = theme.backgroundVideoURL
                }

                AppLogger.shared.info("Wheel data refreshed successfully", category: .ui)

            } catch {
                AppLogger.shared.error("Failed to refresh wheel data: \(error)", category: .ui)
                self.error = "Не удалось обновить данные колеса: \(error.localizedDescription)"
            }
        }
    }

    func refreshWheelDataSilently() async {
        do {
            AppLogger.shared.debug("Silently refreshing wheel data for ID: \(wheelData.id)", category: .ui)
            let updatedWheelData = try await wheelService.getWheelById(wheelData.id)

            // Обновляем секторы
            wheelState.setSectors(updatedWheelData.sectors)

            // Обновляем тему если она изменилась
            if let theme = updatedWheelData.theme {
                wheelState.accentColor = theme.accentColor
                wheelState.mainColor = theme.mainColor
                wheelState.font = theme.font
                wheelState.backVideo = theme.backgroundVideoURL
            }

            AppLogger.shared.info("Wheel data silently refreshed successfully", category: .ui)

        } catch {
            AppLogger.shared.error("Failed to silently refresh wheel data: \(error)", category: .ui)
            // Не показываем ошибку пользователю при тихом обновлении
            // При ошибке сети просто логируем и продолжаем работу
        }
    }

    // MARK: - Cleanup

    func cleanup() {
        AppLogger.shared.debug("Starting cleanup", category: .ui)

        // Принудительно останавливаем вращение колеса
        wheelState.forceStopSpinning()
        wheelState.cleanup()
        socketService.disconnect()
        cancellables.removeAll()

        // Отписываемся от уведомлений
        NotificationCenter.default.removeObserver(
            self, name: .roomUsersUpdated, object: nil)

        AppLogger.shared.debug("Cleanup completed", category: .ui)
    }
}
