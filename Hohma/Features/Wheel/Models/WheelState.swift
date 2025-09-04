//
//  WheelState.swift
//  Hohma
//
//  Created by Artem Vydro on 06.08.2025.
//

import Foundation
import SwiftUI

// MARK: - Notification Names Extension
extension Notification.Name {
    static let sectorEliminated = Notification.Name("sectorEliminated")
    static let wheelCompleted = Notification.Name("wheelCompleted")
    static let wheelDataUpdated = Notification.Name("wheelDataUpdated")
    static let navigationRequested = Notification.Name("navigationRequested")
    static let sectorsUpdated = Notification.Name("sectorsUpdated")
}

@MainActor
class WheelState: ObservableObject {

    // MARK: - Published Properties
    @Published var sectors: [Sector] = []
    @Published var losers: [Sector] = []
    @Published var rotation: Double = 0
    @Published var spinning: Bool = false
    @Published var speed: Double = 10
    @Published var autoSpin: Bool = false
    @Published var accentColor: String = "#ff8181"
    @Published var mainColor: String = "rgba(22, 36, 86, 0.3)"
    @Published var font: String = "pacifico"
    @Published var backVideo: String = "/themeVideo/CLASSIC.mp4"

    // MARK: - Callbacks
    var setEliminated: ((String) -> Void)?
    var setWinner: ((String) -> Void)?
    var setWheelStatus: ((WheelStatus, String) -> Void)?
    var payoutBets: ((String, String) -> Void)?

    // MARK: - Socket.IO properties
    var socket: SocketIOServiceV2?
    var roomId: String?
    var clientId: String?
    private var isAuthorized = true

    // MARK: - Initialization
    init() {
        setupNotificationObservers()
    }

    // MARK: - Setup
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            forName: .sectorEliminated,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                if let sectorId = notification.object as? String {
                    self?.setEliminated?(sectorId)
                }
            }
        }

        NotificationCenter.default.addObserver(
            forName: .wheelCompleted,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                if let winningSector = notification.object as? Sector {
                    self?.setWheelStatus?(.completed, winningSector.wheelId)
                    self?.payoutBets?(winningSector.wheelId, winningSector.id)
                }
            }
        }
    }

    // MARK: - Sector Management
    func setSectors(_ newSectors: [Sector]) {
        print("🔄 WheelState: Setting \(newSectors.count) sectors from server")
        sectors = newSectors.filter { !$0.eliminated }
        losers = newSectors.filter { $0.eliminated }
    }

    func addSector(_ sector: Sector) {
        print("➕ WheelState: Adding sector \(sector.label) from server")
        print("➕ WheelState: Current sectors count: \(sectors.count)")
        sectors.append(sector)
        print("➕ WheelState: New sectors count: \(sectors.count)")

        // Уведомляем об обновлении секторов
        NotificationCenter.default.post(name: .sectorsUpdated, object: sectors)
    }

    func updateSector(_ sector: Sector) {
        print("✏️ WheelState: Updating sector \(sector.label) from server")
        if !sector.eliminated {
            sectors = sectors.filter { $0.id != sector.id }
            losers = losers.filter { $0.id != sector.id }
            sectors.append(sector)
        } else {
            sectors = sectors.filter { $0.id != sector.id }
            losers = losers.filter { $0.id != sector.id }
            losers.append(sector)
        }
    }

    func removeSector(id: String) {
        print("🗑️ WheelState: Removing sector \(id) from server")
        sectors = sectors.filter { $0.id != id }
        losers = losers.filter { $0.id != id }
    }

    func reorderSectors(by newOrder: [Sector]) {
        print("🔄 WheelState: Reordering sectors by new order")

        // Создаем словарь для быстрого поиска секторов по ID
        let sectorMap = Dictionary(uniqueKeysWithValues: sectors.map { ($0.id, $0) })

        // Сортируем секторы по новому порядку, сохраняя существующие объекты
        let reorderedSectors = newOrder.compactMap { newSector in
            sectorMap[newSector.id]
        }

        // Обновляем массив секторов
        sectors = reorderedSectors

        print("✅ WheelState: Reordered \(sectors.count) sectors")
    }

    func emitSectorRemovalEvent(sectorId: String) {
        if let socket = socket, socket.isConnected, isAuthorized {
            print("📤 WheelState: Emitting sector:removed event")
            // Отправляем в том же формате, что и веб-клиент: (roomId, data)
            socket.emitToRoom(.sectorRemoved, roomId: roomId ?? "", data: sectorId)
        } else {
            print(
                "⚠️ WheelState: Cannot emit sector removal event - socket not connected or not authorized"
            )
        }
    }

    func resetAuthorization() {
        isAuthorized = true
        print("✅ WheelState: Authorization flag reset to true")
    }

    func isSocketAuthorized() -> Bool {
        return isAuthorized
    }

    // MARK: - Wheel Actions
    func spinWheel() {
        guard !spinning && sectors.count > 1 else {
            print("⚠️ WheelState: Cannot spin - spinning: \(spinning), sectors: \(sectors.count)")
            return
        }

        // Принудительно сбрасываем состояние spinning на всякий случай
        spinning = false

        let totalSectors = sectors.count
        let anglePerSector = 360.0 / Double(totalSectors)
        let winningIndex = Int.random(in: 0..<totalSectors)
        let sectorStartAngle = Double(winningIndex) * anglePerSector
        let targetAngle = sectorStartAngle + Double.random(in: 0..<anglePerSector)
        let currentRotation = rotation.truncatingRemainder(dividingBy: 360)
        var delta = -targetAngle - currentRotation
        delta = delta.truncatingRemainder(dividingBy: 360)
        if delta < 0 { delta += 360 }

        print(
            "🎯 WheelState: Target angle: \(targetAngle), current rotation: \(currentRotation), delta: \(delta)"
        )
        // Уменьшаем количество дополнительных оборотов для более плавной анимации
        let extraSpins = 360.0 * 3
        let finalDelta = extraSpins + delta
        let newRotation = rotation + finalDelta

        print(
            "🎲 WheelState: Spinning wheel - current: \(rotation), target: \(newRotation), delta: \(finalDelta)"
        )

        // Emit spin event to other clients
        let spinData: [String: Any] = [
            "rotation": newRotation,
            "speed": speed,
            "winningIndex": winningIndex,
            "clientId": clientId ?? "",
        ]

        emitSpinEvent(spinData)

        spinning = true
        rotation = newRotation
        print("🔄 WheelState: Started spinning - rotation: \(rotation)")

        handleSpinResult(winningIndex: winningIndex, rotation: newRotation, speed: speed)

        if autoSpin {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.spinWheel()
            }
        }
    }

    func shuffleSectors() {
        let shuffledSectors = sectors.shuffled()

        // Emit shuffle event to other clients
        let sectorsData = shuffledSectors.map { sector in
            createSectorDictionaryForShuffle(sector)
        }

        let shuffleData: [String: Any] = [
            "sectors": sectorsData,
            "clientId": clientId ?? "",
        ]

        emitShuffleEvent(shuffleData)

        sectors = shuffledSectors
    }

    // MARK: - Force Stop
    func forceStopSpinning() {
        print("🛑 WheelState: Force stopping wheel spinning")
        spinning = false
    }

    func randomColor() -> (h: Double, s: Double, l: Double) {
        let hue = Double.random(in: 0...360)
        return (h: hue, s: 60, l: 30)
    }

    // MARK: - Private Methods
    private func handleSpinResult(winningIndex: Int, rotation: Double, speed: Double) {
        print(
            "🎯 WheelState: Handling spin result - winningIndex: \(winningIndex), rotation: \(rotation), speed: \(speed)"
        )
        DispatchQueue.main.asyncAfter(deadline: .now() + speed) {
            // Проверяем, что колесо все еще вращается и секторы существуют
            guard self.spinning && winningIndex < self.sectors.count else {
                print(
                    "⚠️ WheelState: Cannot handle spin result - spinning: \(self.spinning), sectors count: \(self.sectors.count)"
                )
                // Принудительно останавливаем вращение если что-то пошло не так
                self.spinning = false
                return
            }

            let eliminatedSector = self.sectors[winningIndex]

            self.sectors.remove(at: winningIndex)
            self.losers.insert(eliminatedSector, at: 0)

            if self.sectors.count == 1 && self.losers.count > 0 {
                // Устанавливаем winner = true для оставшегося сектора
                let winningSector = self.sectors[0]
                let updatedSector = Sector(
                    id: winningSector.id,
                    label: winningSector.label,
                    color: winningSector.color,
                    name: winningSector.name,
                    eliminated: winningSector.eliminated,
                    winner: true,  // Устанавливаем winner = true
                    description: winningSector.description,
                    pattern: winningSector.pattern,
                    patternPosition: winningSector.patternPosition,
                    poster: winningSector.poster,
                    genre: winningSector.genre,
                    rating: winningSector.rating,
                    year: winningSector.year,
                    labelColor: winningSector.labelColor,
                    labelHidden: winningSector.labelHidden,
                    wheelId: winningSector.wheelId,
                    userId: winningSector.userId,
                    user: winningSector.user,
                    createdAt: winningSector.createdAt,
                    updatedAt: winningSector.updatedAt
                )
                self.sectors[0] = updatedSector
                self.setWinner?(self.sectors[0].id)
                self.setWheelStatus?(.completed, self.sectors[0].wheelId)
                self.payoutBets?(self.sectors[0].wheelId, self.sectors[0].id)
            } else {
                self.setWheelStatus?(.active, self.sectors[0].wheelId)
            }

            // Оставляем колесо на той позиции, где оно остановилось
            print("🔄 WheelState: Wheel stopped at rotation: \(self.rotation)")

            // Останавливаем вращение немедленно
            self.spinning = false

            self.setEliminated?(eliminatedSector.id)
        }
    }

    private func createSectorDictionary(_ sector: Sector) -> [String: Any] {
        return [
            "id": sector.id,
            "label": sector.label,
            "color": "#000000",
            "name": sector.name,
            "eliminated": sector.eliminated,
            "winner": sector.winner,
            "description": sector.description ?? "",
            "pattern": sector.pattern ?? "",
            "labelColor": sector.labelColor ?? "",
            "labelHidden": sector.labelHidden,
            "wheelId": sector.wheelId,
            "userId": sector.userId ?? "",
        ]
    }

    private func createSectorDictionaryForShuffle(_ sector: Sector) -> [String: Any] {
        return [
            "id": sector.id,
            "label": sector.label,
            "color": [
                "h": sector.color.h,
                "s": sector.color.s,
                "l": sector.color.l,
            ],
            "name": sector.name,
            "eliminated": sector.eliminated,
            "winner": sector.winner,
            "description": sector.description ?? "",
            "pattern": sector.pattern ?? "",
            "patternPosition": sector.patternPosition.map { pos in
                [
                    "x": pos.x,
                    "y": pos.y,
                    "z": pos.z,
                ]
            } ?? [],
            "poster": sector.poster ?? "",
            "genre": sector.genre ?? "",
            "rating": sector.rating ?? "",
            "year": sector.year ?? "",
            "labelColor": sector.labelColor ?? "",
            "labelHidden": sector.labelHidden,
            "wheelId": sector.wheelId,
            "userId": sector.userId ?? "",
            "user": sector.user.map { user in
                [
                    "id": user.id,
                    "username": user.username ?? "",
                    "firstName": user.firstName ?? "",
                    "lastName": user.lastName ?? "",
                    "coins": user.coins,
                    "clicks": user.clicks,
                    "createdAt": "",
                    "updatedAt": "",
                    "avatarUrl": user.avatarUrl?.absoluteString ?? "",
                    "role": user.role,
                ] as [String: Any]
            } as Any,
            "createdAt": ISO8601DateFormatter().string(from: sector.createdAt),
            "updatedAt": ISO8601DateFormatter().string(from: sector.updatedAt),
        ]
    }

    private func createSectorsArray(_ sectors: [Sector]) -> [[String: Any]] {
        return sectors.map { createSectorDictionary($0) }
    }

    private func emitSpinEvent(_ spinData: [String: Any]) {
        print("🔍 WheelState: Debug info for spin event:")
        print("   - socket exists: \(socket != nil)")
        print("   - socket.isConnected: \(socket?.isConnected ?? false)")
        print("   - isAuthorized: \(isAuthorized)")
        print("   - roomId: \(roomId ?? "nil")")

        if let socket = socket, socket.isConnected, isAuthorized {
            print("📤 WheelState: Emitting wheel:spin event")
            // Отправляем в том же формате, что и веб-клиент: (roomId, data)
            socket.emitToRoom(.wheelSpin, roomId: roomId ?? "", data: spinData)
        } else {
            print("⚠️ WheelState: Cannot emit spin event - socket not connected")
        }
    }

    private func emitShuffleEvent(_ shuffleData: [String: Any]) {
        print("🔍 WheelState: Debug info for shuffle event:")
        print("   - socket exists: \(socket != nil)")
        print("   - socket.isConnected: \(socket?.isConnected ?? false)")
        print("   - isAuthorized: \(isAuthorized)")
        print("   - roomId: \(roomId ?? "nil")")

        if let socket = socket, socket.isConnected, isAuthorized {
            print("📤 WheelState: Emitting sectors:shuffle event")
            // Отправляем в том же формате, что и веб-клиент: (roomId, data)
            socket.emitToRoom(.sectorsShuffle, roomId: roomId ?? "", data: shuffleData)
        } else {
            print("⚠️ WheelState: Cannot emit shuffle event - socket not connected")
        }
    }

    // MARK: - Socket Integration (упрощенная версия)
    func setupSocket(_ socket: SocketIOServiceV2, roomId: String) {
        print("🔧 WheelState: Setting up socket...")
        print("   - roomId: \(roomId)")
        print("   - clientId: \(socket.clientId)")

        self.socket = socket
        self.roomId = roomId
        self.clientId = socket.clientId

        setupSocketEventHandlers()
        print("✅ WheelState: Socket setup completed")
    }

    func joinRoom(_ roomId: String, userId: AuthUser?) {
        print("🔌 WheelState: Attempting to join room \(roomId)")
        print("   - socket exists: \(socket != nil)")
        print("   - socket.isConnected: \(socket?.isConnected ?? false)")
        print("   - isAuthorized: \(isAuthorized)")

        var userData: [String: Any] = [:]
        if let user = userId {
            userData = [
                "id": user.id,
                "username": user.username ?? "",
                "firstName": user.firstName ?? "",
                "lastName": user.lastName ?? "",
                "coins": user.coins,
                "avatarUrl": user.avatarUrl?.absoluteString ?? "",
                "role": user.role,
            ]
        }

        let joinData: [String: Any] = [
            "roomId": roomId,
            "userId": userData,
            "clientId": clientId ?? "",
        ]

        if let socket = socket, socket.isConnected {
            // Сбрасываем флаг авторизации при попытке подключения к комнате
            isAuthorized = true
            print("🔌 WheelState: Joining room \(roomId)")
            socket.emit(.joinRoom, data: joinData)

            // Request sectors after joining room
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.requestSectors()
            }
        } else {
            print("⚠️ WheelState: Cannot join room - socket not connected")
        }
    }

    func leaveRoom() {
        if let roomId = roomId {
            let leaveData: [String: Any] = ["roomId": roomId]

            if let socket = socket, socket.isConnected, isAuthorized {
                socket.emit(.leaveRoom, data: leaveData)
            } else {
                print("⚠️ WheelState: Cannot leave room - socket not connected or not authorized")
            }
        }
    }

    func requestSectors() {
        print("📋 WheelState: Requesting sectors from server")

        guard let roomId = roomId else {
            print("⚠️ WheelState: Cannot request sectors - no roomId")
            return
        }

        Task {
            do {
                let updatedSectors = try await FortuneWheelService.shared.getSectorsByWheelId(
                    roomId)
                print("✅ WheelState: Received \(updatedSectors.count) sectors from server")

                DispatchQueue.main.async {
                    self.setSectors(updatedSectors)
                    print("✅ WheelState: Updated sectors from server")
                }
            } catch {
                print("❌ WheelState: Failed to fetch sectors from server: \(error)")
            }
        }
    }

    func spinWheelFromServer(_ spinData: [String: Any]) {
        guard let rotation = spinData["rotation"] as? Double,
            let speed = spinData["speed"] as? Double,
            let winningIndex = spinData["winningIndex"] as? Int
        else {
            print("❌ WheelState: Invalid spin data received from server")
            return
        }

        let generatedByServer = spinData["generatedByServer"] as? Bool ?? false
        print(
            "🎯 WheelState: Received spin result from server: rotation=\(rotation), speed=\(speed), winningIndex=\(winningIndex), generatedByServer=\(generatedByServer)"
        )

        spinning = true
        self.rotation = rotation

        handleSpinResult(winningIndex: winningIndex, rotation: rotation, speed: speed)
    }

    func shuffleSectorsFromServer(_ data: [String: Any]) {
        let senderClientId = data["senderClientId"] as? String ?? data["clientId"] as? String

        guard let senderClientId = senderClientId,
            let sectorsData = data["sectors"] as? [[String: Any]]
        else {
            print("❌ WheelState: Invalid shuffle data received")
            return
        }

        // Only update if the event came from another client
        if senderClientId != clientId {
            print("🔄 WheelState: Received shuffle data from server: \(sectorsData.count) sectors")

            do {
                let decoder = JSONDecoder()
                // Используем .iso8601withMilliseconds для ISO 8601 строк
                decoder.dateDecodingStrategy = .iso8601withMilliseconds

                // Конвертируем обратно в JSON Data для декодирования
                let sectorsJsonData = try JSONSerialization.data(withJSONObject: sectorsData)
                let shuffledSectors = try decoder.decode([Sector].self, from: sectorsJsonData)

                DispatchQueue.main.async {
                    // Вместо замены массива, сортируем существующий массив по новому порядку
                    self.reorderSectors(by: shuffledSectors)
                    print(
                        "✅ WheelState: Reordered sectors from shuffle event (\(shuffledSectors.count) sectors)"
                    )
                    // Debug: print labels to verify they are reordered correctly
                    for (index, sector) in self.sectors.enumerated() {
                        print(
                            "🔍 Sector \(index): label='\(sector.label)', name='\(sector.name)', labelHidden=\(sector.labelHidden)"
                        )
                    }
                }
            } catch {
                print("❌ WheelState: Failed to decode shuffle sectors: \(error)")
            }
        } else {
            print("🔄 WheelState: Ignoring shuffle event from self")
        }
    }

    private func setupSocketEventHandlers() {
        print("🔧 WheelState: Setting up socket event handlers")
        guard let socket = socket else {
            print("❌ WheelState: Cannot setup handlers - socket is nil")
            return
        }
        print("✅ WheelState: Socket event handlers setup completed")

        // Handle connect event
        socket.on(.connect) { [weak self] data in
            print("🔌 WheelState: Socket connected, ready to join room")
            // Сбрасываем флаг авторизации при успешном подключении
            self?.isAuthorized = true
            print("✅ WheelState: Authorization flag reset to true")
        }

        // Handle wheel spin from server
        socket.on(.wheelSpin) { [weak self] data in
            print("🔄 WheelState: Received wheelSpin event")
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    DispatchQueue.main.async {
                        self?.spinWheelFromServer(json)
                    }
                }
            } catch {
                print("❌ WheelState: Failed to decode spin data: \(error)")
            }
        }

        // Handle sectors shuffle from server
        socket.on(.sectorsShuffle) { [weak self] data in
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    DispatchQueue.main.async {
                        self?.shuffleSectorsFromServer(json)
                    }
                }
            } catch {
                print("❌ WheelState: Failed to decode shuffle data: \(error)")
            }
        }

        // Handle sectors sync
        socket.on(.syncSectors) { [weak self] data in
            print("📥 WheelState: Received sectors:sync event")
            // Просто запрашиваем актуальные данные с сервера
            DispatchQueue.main.async {
                self?.requestSectors()
            }
        }

        // Handle sector updates
        socket.on(.sectorUpdated) { [weak self] data in
            print("📥 WheelState: Received sector:updated event")
            // Просто запрашиваем свежие данные с сервера для единообразия
            DispatchQueue.main.async {
                self?.requestSectors()
            }
        }

        // Handle sector creation
        socket.on(.sectorCreated) { [weak self] data in
            print("📥 WheelState: Received sector:created event")
            // Просто запрашиваем свежие данные с сервера для единообразия
            DispatchQueue.main.async {
                self?.requestSectors()
            }
        }

        // Handle sector removal
        socket.on(.sectorRemoved) { [weak self] data in
            print("📥 WheelState: Received sector:removed event")
            // Просто запрашиваем свежие данные с сервера для единообразия
            DispatchQueue.main.async {
                self?.requestSectors()
            }
        }

        // Handle room users
        socket.on(.roomUsers) { data in
            print("👥 WheelState: Received room users update")

            do {
                let roomUsers = try JSONDecoder().decode([RoomUser].self, from: data)
                let users = roomUsers.map { $0.toAuthUser() }

                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .roomUsersUpdated, object: users)
                }
            } catch {
                print("❌ WheelState: Failed to decode room users: \(error)")
            }
        }

        // Handle request:sectors - respond with current sectors
        socket.on(.requestSectors) { [weak self] data in
            print("📋 WheelState: Received request:sectors, responding with current sectors")

            guard let self = self,
                let socket = self.socket,
                socket.isConnected,
                self.isAuthorized
            else {
                print(
                    "⚠️ WheelState: Cannot respond to sectors request - not connected or not authorized"
                )
                return
            }

            // Отправляем текущие секторы в ответ на запрос
            // Веб-клиент ожидает массив секторов напрямую
            let sectorsArray = self.sectors.map { sector in
                self.createSectorDictionaryForShuffle(sector)
            }

            print("📤 WheelState: Sending \(self.sectors.count) sectors in response")
            // Отправляем массив секторов напрямую, как веб-клиент
            socket.emit(.currentSectors, data: sectorsArray)
        }

        // Handle current:sectors - receive sectors from other clients
        socket.on(.currentSectors) { [weak self] data in
            print("📋 WheelState: Received current:sectors from another client")

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    // Проверяем оба возможных формата
                    var sectorsArray: [[String: Any]]?

                    if let directSectors = json["sectors"] as? [[String: Any]] {
                        // Прямой формат: { "sectors": [...] }
                        sectorsArray = directSectors
                    } else if let nestedSectors = json["sectors"] as? [String: Any],
                        let nestedArray = nestedSectors["sectors"] as? [[String: Any]]
                    {
                        // Вложенный формат: { "sectors": { "sectors": [...] } }
                        sectorsArray = nestedArray
                    } else if let directArray = try? JSONSerialization.jsonObject(with: data)
                        as? [[String: Any]]
                    {
                        // Прямой массив секторов
                        sectorsArray = directArray
                    }

                    if let sectorsArray = sectorsArray {
                        let decoder = JSONDecoder()
                        // Используем .iso8601withMilliseconds для ISO 8601 строк
                        decoder.dateDecodingStrategy = .iso8601withMilliseconds

                        // Конвертируем обратно в JSON Data для декодирования
                        let sectorsData = try JSONSerialization.data(withJSONObject: sectorsArray)
                        let sectors = try decoder.decode([Sector].self, from: sectorsData)

                        DispatchQueue.main.async {
                            // Вместо замены массива, сортируем существующий массив по новому порядку
                            self?.reorderSectors(by: sectors)
                            print(
                                "✅ WheelState: Reordered sectors from other client (\(sectors.count) sectors)"
                            )
                        }
                    } else {
                        print("❌ WheelState: Could not find sectors array in response")
                    }
                }
            } catch {
                print("❌ WheelState: Failed to decode current:sectors data: \(error)")
            }
        }

        // Subscribe to socket authorization errors
        NotificationCenter.default.addObserver(
            forName: .socketAuthorizationError,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                print("🔐 WheelState: Socket authorization error detected")
                self?.isAuthorized = false
                self?.cleanup()
            }
        }
    }

    // MARK: - Cleanup
    func cleanup() {
        // Принудительно останавливаем вращение
        forceStopSpinning()

        leaveRoom()
        socket = nil
        roomId = nil
        clientId = nil
        isAuthorized = false

        // Remove notification observers
        NotificationCenter.default.removeObserver(self, name: .sectorEliminated, object: nil)
        NotificationCenter.default.removeObserver(self, name: .wheelCompleted, object: nil)
        NotificationCenter.default.removeObserver(
            self, name: .socketAuthorizationError, object: nil)
    }
}
