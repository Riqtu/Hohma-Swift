//
//  MovieBattleSocketManager.swift
//  Hohma
//
//  Created by Assistant
//

import Foundation

class MovieBattleSocketManager {
    private var socket: SocketIOServiceAdapter
    private let battleId: String
    private let userId: String
    private let roomId: String
    
    // Callbacks
    var onBattleUpdate: ((MovieBattle) -> Void)?
    var onMovieAdded: ((MovieBattle) -> Void)?
    var onGenerationStarted: ((MovieBattle) -> Void)?
    var onGenerationProgress: ((String, GenerationStatus, MovieCard?) -> Void)?
    var onVotingStarted: ((MovieBattle) -> Void)?
    var onVoteCast: ((MovieBattle) -> Void)?
    var onRoundComplete: ((MovieBattle, String, Int, Bool) -> Void)?
    
    init(socket: SocketIOServiceAdapter, battleId: String, userId: String) {
        self.socket = socket
        self.battleId = battleId
        self.userId = userId
        self.roomId = "movieBattle:\(battleId)"
    }
    
    func setupHandlers() {
        // Обработка подключения - присоединяемся к комнате после подключения
        socket.on(.connect) { [weak self] _ in
            AppLogger.shared.debug("📡 MovieBattleSocketManager: Socket connected event received, joining room...", category: .socket)
            // Не проверяем isConnected, так как событие connect уже означает подключение
            // Добавляем небольшую задержку для стабилизации соединения
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 секунды
                self.joinRoomImmediately()
            }
        }
        
        // Обработка обновления игры
        socket.on(.movieBattleUpdate) { [weak self] data in
            self?.handleBattleUpdate(data)
        }
        
        // Обработка добавления фильма
        socket.on(.movieBattleMovieAdded) { [weak self] data in
            self?.handleMovieAdded(data)
        }
        
        // Обработка начала генерации
        socket.on(.movieBattleGenerationStarted) { [weak self] data in
            self?.handleGenerationStarted(data)
        }
        
        // Обработка прогресса генерации
        socket.on(.movieBattleGenerationProgress) { [weak self] data in
            self?.handleGenerationProgress(data)
        }
        
        // Обработка начала голосования
        socket.on(.movieBattleVotingStarted) { [weak self] data in
            self?.handleVotingStarted(data)
        }
        
        // Обработка голоса
        socket.on(.movieBattleVoteCast) { [weak self] data in
            self?.handleVoteCast(data)
        }
        
        // Обработка завершения раунда
        socket.on(.movieBattleRoundComplete) { [weak self] data in
            self?.handleRoundComplete(data)
        }
    }
    
    func connectIfNeeded() {
        setupHandlers()
        
        if !socket.isConnected && !socket.isConnecting {
            socket.connect()
        } else if socket.isConnected {
            // Если уже подключен, сразу присоединяемся к комнате
            joinRoom()
        }
    }
    
    func joinRoom() {
        // Проверяем подключение, но если событие connect пришло, пробуем присоединиться в любом случае
        if !socket.isConnected {
            AppLogger.shared.warning("Socket reports not connected, but trying to join room anyway (connect event received)", category: .socket)
        }
        
        joinRoomImmediately()
    }
    
    private func joinRoomImmediately() {
        AppLogger.shared.debug("📡 MovieBattleSocketManager: Joining room: \(roomId)", category: .socket)
        // Присоединяемся к комнате
        let payload: [String: Any] = [
            "roomId": roomId,
            "userId": userId,
        ]
        socket.emit(.joinRoom, data: payload)
        AppLogger.shared.info("Join room event emitted", category: .socket)
    }
    
    func disconnect() {
        let payload: [String: Any] = ["roomId": roomId]
        socket.emit(.leaveRoom, data: payload)
    }
    
    // MARK: - Handlers
    
    private func handleBattleUpdate(_ data: Data) {
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                AppLogger.shared.debug("📡 MovieBattleSocketManager: Received battle update event", category: .socket)
                
                if let battleData = json["battle"] as? [String: Any] {
                    do {
                        let battleJson = try JSONSerialization.data(withJSONObject: battleData)
                        let battle = try JSONDecoder().decode(MovieBattle.self, from: battleJson)
                        AppLogger.shared.info("Successfully decoded battle update", category: .socket)
                        Task { @MainActor in
                            self.onBattleUpdate?(battle)
                        }
                    } catch {
                        AppLogger.shared.error("Failed to decode battle from update event: \(error.localizedDescription)", category: .socket)
                    }
                }
            }
        } catch {
            AppLogger.shared.error("Failed to parse battle update: \(error)", category: .socket)
        }
    }
    
    private func handleMovieAdded(_ data: Data) {
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let battleData = json["battle"] as? [String: Any] {
                do {
                    let battleJson = try JSONSerialization.data(withJSONObject: battleData)
                    let battle = try JSONDecoder().decode(MovieBattle.self, from: battleJson)
                    Task { @MainActor in
                        self.onMovieAdded?(battle)
                    }
                } catch {
                    AppLogger.shared.error("Failed to decode battle in movie added: \(error.localizedDescription)", category: .socket)
                }
            }
        } catch {
            AppLogger.shared.error("Failed to parse movie added: \(error.localizedDescription)", category: .socket)
        }
    }
    
    private func handleGenerationStarted(_ data: Data) {
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let battleData = json["battle"] as? [String: Any] {
                do {
                    let battleJson = try JSONSerialization.data(withJSONObject: battleData)
                    let battle = try JSONDecoder().decode(MovieBattle.self, from: battleJson)
                    Task { @MainActor in
                        self.onGenerationStarted?(battle)
                    }
                } catch {
                    AppLogger.shared.error("Failed to decode battle in generation started: \(error.localizedDescription)", category: .socket)
                }
            }
        } catch {
            AppLogger.shared.error("Failed to parse generation started: \(error.localizedDescription)", category: .socket)
        }
    }
    
    private func handleGenerationProgress(_ data: Data) {
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                AppLogger.shared.debug("📡 MovieBattleSocketManager: Received generation progress event: \(json)", category: .socket)
                
                guard let movieCardId = json["movieCardId"] as? String,
                      let statusString = json["status"] as? String else {
                    AppLogger.shared.warning("Missing movieCardId or status in event", category: .socket)
                    return
                }
                
                // Поддерживаем как старые, так и новые статусы
                var status: GenerationStatus
                if let parsedStatus = GenerationStatus(rawValue: statusString) {
                    status = parsedStatus
                } else {
                    // Если статус не распознан, определяем по контексту
                    if json["hasTitle"] as? Bool == true {
                        status = .titleReady
                    } else if json["hasPoster"] as? Bool == true {
                        status = .posterReady
                    } else if json["hasDescription"] as? Bool == true {
                        status = .descriptionReady
                    } else {
                        status = .generating
                    }
                }
                
                AppLogger.shared.debug("📡 MovieBattleSocketManager: Parsed status: \(status.rawValue) for movieCardId: \(movieCardId)", category: .socket)
                
                // Пытаемся декодировать movieCard, если он есть в событии
                var movieCard: MovieCard? = nil
                if let movieCardData = json["movieCard"] as? [String: Any] {
                    AppLogger.shared.debug("📡 MovieBattleSocketManager: Found movieCard in event, decoding...", category: .socket)
                    do {
                        let movieCardJson = try JSONSerialization.data(withJSONObject: movieCardData)
                        let decodedCard = try JSONDecoder().decode(MovieCard.self, from: movieCardJson)
                        movieCard = decodedCard
                        AppLogger.shared.info("Successfully decoded movieCard", category: .socket)
                    } catch {
                        AppLogger.shared.warning("Failed to decode movieCard: \(error.localizedDescription)", category: .socket)
                    }
                } else {
                    AppLogger.shared.debug("ℹ️ MovieBattleSocketManager: No movieCard in event", category: .socket)
                }
                
                Task { @MainActor in
                    AppLogger.shared.debug("📡 MovieBattleSocketManager: Calling onGenerationProgress callback", category: .socket)
                    self.onGenerationProgress?(movieCardId, status, movieCard)
                }
            }
        } catch {
            AppLogger.shared.error("Failed to parse generation progress: \(error)", category: .socket)
        }
    }
    
    private func handleVotingStarted(_ data: Data) {
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let battleData = json["battle"] as? [String: Any] {
                do {
                    let battleJson = try JSONSerialization.data(withJSONObject: battleData)
                    let battle = try JSONDecoder().decode(MovieBattle.self, from: battleJson)
                    Task { @MainActor in
                        self.onVotingStarted?(battle)
                    }
                } catch {
                    AppLogger.shared.error("Failed to decode battle in voting started: \(error.localizedDescription)", category: .socket)
                }
            }
        } catch {
            AppLogger.shared.error("Failed to parse voting started: \(error.localizedDescription)", category: .socket)
        }
    }
    
    private func handleVoteCast(_ data: Data) {
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let battleData = json["battle"] as? [String: Any] {
                do {
                    let battleJson = try JSONSerialization.data(withJSONObject: battleData)
                    let battle = try JSONDecoder().decode(MovieBattle.self, from: battleJson)
                    Task { @MainActor in
                        self.onVoteCast?(battle)
                    }
                } catch {
                    AppLogger.shared.error("Failed to decode battle in vote cast: \(error.localizedDescription)", category: .socket)
                }
            }
        } catch {
            AppLogger.shared.error("Failed to parse vote cast: \(error.localizedDescription)", category: .socket)
        }
    }
    
    private func handleRoundComplete(_ data: Data) {
        do {
            // Событие может прийти как массив или как объект
            let json = try JSONSerialization.jsonObject(with: data)
            
            AppLogger.shared.debug("📡 MovieBattleSocketManager: Received round complete event: \(json)", category: .socket)
            
            var battleData: [String: Any]?
            var eliminatedMovieId: String?
            var roundNumber: Int?
            var isFinished: Bool?
            
            // Проверяем, является ли это массивом
            if let jsonArray = json as? [Any], jsonArray.count >= 2 {
                AppLogger.shared.debug("📡 MovieBattleSocketManager: Event data is array with \(jsonArray.count) elements", category: .socket)
                // Первый элемент - объект battle
                if let firstElement = jsonArray[0] as? [String: Any] {
                    battleData = firstElement
                    AppLogger.shared.info("Extracted battle data from array[0]", category: .socket)
                } else {
                    AppLogger.shared.warning("Array[0] is not a dictionary", category: .socket)
                }
                
                // Второй элемент - объект с eliminatedMovieId, roundNumber, isFinished
                if let secondElement = jsonArray[1] as? [String: Any] {
                    eliminatedMovieId = secondElement["eliminatedMovieId"] as? String
                    roundNumber = secondElement["roundNumber"] as? Int
                    // isFinished может быть Int или Bool
                    if let isFinishedInt = secondElement["isFinished"] as? Int {
                        isFinished = isFinishedInt != 0
                    } else if let isFinishedBool = secondElement["isFinished"] as? Bool {
                        isFinished = isFinishedBool
                    }
                    AppLogger.shared.info("Extracted metadata from array[1]: eliminatedMovieId=\(eliminatedMovieId ?? "nil"), roundNumber=\(roundNumber?.description ?? "nil"), isFinished=\(isFinished?.description ?? "nil")", category: .socket)
                } else {
                    AppLogger.shared.warning("Array[1] is not a dictionary: \(jsonArray[1])", category: .socket)
                }
            } else if let jsonDict = json as? [String: Any] {
                AppLogger.shared.debug("📡 MovieBattleSocketManager: Event data is dictionary", category: .socket)
                // Если это объект, ищем battle внутри
                battleData = jsonDict["battle"] as? [String: Any]
                eliminatedMovieId = jsonDict["eliminatedMovieId"] as? String
                roundNumber = jsonDict["roundNumber"] as? Int
                // isFinished может быть Int или Bool
                if let isFinishedInt = jsonDict["isFinished"] as? Int {
                    isFinished = isFinishedInt != 0
                } else if let isFinishedBool = jsonDict["isFinished"] as? Bool {
                    isFinished = isFinishedBool
                }
            } else {
                AppLogger.shared.warning("Event data is neither array nor dictionary: \(type(of: json))", category: .socket)
            }
            
            guard let battleData = battleData,
                  let eliminatedMovieId = eliminatedMovieId,
                  let roundNumber = roundNumber else {
                AppLogger.shared.warning("Missing required fields in round complete event", category: .socket)
                AppLogger.shared.debug("\(battleData != nil), eliminatedMovieId: \(eliminatedMovieId ?? "nil"), roundNumber: \(roundNumber?.description ?? "nil"), isFinished: \(isFinished?.description ?? "nil")", category: .socket)
                return
            }
            
            // isFinished уже обработан выше, но на всякий случай проверяем еще раз
            let isFinishedBool: Bool = isFinished ?? false
            
            let battleJson: Data
            do {
                battleJson = try JSONSerialization.data(withJSONObject: battleData)
            } catch {
                AppLogger.shared.error("Failed to serialize battle data to JSON: \(error.localizedDescription)", category: .socket)
                return
            }
            
            let battle: MovieBattle
            do {
                battle = try JSONDecoder().decode(MovieBattle.self, from: battleJson)
            } catch {
                AppLogger.shared.warning("Failed to decode battle from round complete event: \(error)", category: .socket)
                if let jsonString = String(data: battleJson, encoding: .utf8) {
                    AppLogger.shared.debug("Battle JSON (first 1000 chars): \(String(jsonString.prefix(1000)))", category: .socket)
                }
                // Пытаемся декодировать с более детальной информацией об ошибке
                if let decodingError = error as? DecodingError {
                    switch decodingError {
                    case .keyNotFound(let key, let context):
                        AppLogger.shared.debug("Missing key: \(key.stringValue) at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))", category: .socket)
                    case .typeMismatch(let type, let context):
                        AppLogger.shared.debug("Type mismatch: expected \(type) at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))", category: .socket)
                    case .valueNotFound(let type, let context):
                        AppLogger.shared.debug("Value not found: \(type) at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))", category: .socket)
                    case .dataCorrupted(let context):
                        AppLogger.shared.error("Data corrupted at path: \(context.codingPath.map { $0.stringValue }.joined(separator: ".")), error: \(context.debugDescription)", category: .socket)
                    @unknown default:
                        AppLogger.shared.error("Unknown decoding error: \(decodingError)", category: .socket)
                    }
                }
                return
            }
            
            AppLogger.shared.info("Parsed round complete - roundNumber: \(roundNumber), eliminatedMovieId: \(eliminatedMovieId), isFinished: \(isFinishedBool)", category: .socket)
            
            DispatchQueue.main.async {
                self.onRoundComplete?(battle, eliminatedMovieId, roundNumber, isFinishedBool)
            }
        } catch {
            AppLogger.shared.error("Failed to parse round complete: \(error)", category: .socket)
        }
    }
}


