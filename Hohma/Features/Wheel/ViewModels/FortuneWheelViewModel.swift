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

        // Инициализируем SocketIOService с правильным URL
        let socketURL = wheelService.getSocketURL()
        self.socketService = SocketIOService(baseURL: socketURL)

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
                    self?.joinRoom()
                }
            }
            .store(in: &cancellables)

        socketService.$error
            .sink { [weak self] error in
                self?.error = error
            }
            .store(in: &cancellables)

        // Настраиваем сокет для wheelState
        wheelState.setupSocket(socketService, roomId: wheelData.id)

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
            } catch {
                self.error = "Ошибка обновления сектора: \(error.localizedDescription)"
            }
        }
    }

    private func handleWheelStatusChange(_ status: WheelStatus, wheelId: String) {
        Task {
            do {
                let updatedWheel = try await wheelService.updateWheelStatus(wheelId, status: status)
                print("Статус колеса обновлен: \(updatedWheel.status)")
            } catch {
                self.error = "Ошибка обновления статуса колеса: \(error.localizedDescription)"
            }
        }
    }

    private func handlePayoutBets(wheelId: String, winningSectorId: String) {
        Task {
            do {
                try await wheelService.payoutBets(
                    wheelId: wheelId, winningSectorId: winningSectorId)
                print("Ставки выплачены для сектора: \(winningSectorId)")
            } catch {
                self.error = "Ошибка выплаты ставок: \(error.localizedDescription)"
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
        !wheelState.spinning && isGameActive && isSocketReady
    }

    // MARK: - Cleanup

    func cleanup() {
        wheelState.cleanup()
        socketService.disconnect()
        cancellables.removeAll()
    }
}
