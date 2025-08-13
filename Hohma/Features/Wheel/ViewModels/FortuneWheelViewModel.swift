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
    @Published var isLoading = false
    @Published var error: String?
    @Published var isVideoReady: Bool = false
    @Published var hasError: Bool = false
    @Published var isSocketReady = false

    // Services
    private var streamPlayer: StreamPlayer?
    private var streamVideoService = StreamVideoService.shared
    private var socketService: SocketIOService
    private var wheelService = FortuneWheelService()
    private var cancellables = Set<AnyCancellable>()

    private let wheelData: WheelWithRelations
    private let currentUser: AuthUser?

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

        self.socketService = SocketIOService(baseURL: socketURL, authToken: authToken)

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

        // Подписываемся на уведомления об ошибках авторизации сокета
        NotificationCenter.default.addObserver(
            forName: .socketAuthorizationError,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("🔐 FortuneWheelViewModel: Socket authorization error detected")
            // Сначала отключаем сокет, затем очищаем ресурсы
            self?.socketService.disconnect()
            self?.cleanup()
        }

        // Подключаемся к сокету
        socketService.connect()
    }

    private func joinRoom() {
        wheelState.joinRoom(wheelData.id, userId: currentUser)
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

    func calculateWheelSize(for geometry: GeometryProxy) -> CGFloat {
        let minDimension = min(geometry.size.width, geometry.size.height)
        let wheelSize = minDimension * 0.35  // 35% от меньшей стороны экрана
        return max(200, min(wheelSize, 300))  // Ограничиваем размер
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

    private func handleWheelStatusChange(_ status: WheelStatus, wheelId: String) {
        Task {
            do {
                let updatedWheel = try await wheelService.updateWheelStatus(wheelId, status: status)
                print("Статус колеса обновлен: \(updatedWheel.status)")
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
        socketService.disconnect()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.socketService.connect()
        }
    }

    // MARK: - Cleanup

    func cleanup() {
        wheelState.cleanup()
        socketService.disconnect()
        cancellables.removeAll()

        // Отписываемся от уведомлений
        NotificationCenter.default.removeObserver(
            self, name: .socketAuthorizationError, object: nil)
    }
}
