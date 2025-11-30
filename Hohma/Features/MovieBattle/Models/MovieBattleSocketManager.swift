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
            print("📡 MovieBattleSocketManager: Socket connected event received, joining room...")
            // Не проверяем isConnected, так как событие connect уже означает подключение
            // Добавляем небольшую задержку для стабилизации соединения
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self?.joinRoomImmediately()
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
            print("⚠️ MovieBattleSocketManager: Socket reports not connected, but trying to join room anyway (connect event received)")
        }
        
        joinRoomImmediately()
    }
    
    private func joinRoomImmediately() {
        print("📡 MovieBattleSocketManager: Joining room: \(roomId)")
        // Присоединяемся к комнате
        let payload: [String: Any] = [
            "roomId": roomId,
            "userId": userId,
        ]
        socket.emit(.joinRoom, data: payload)
        print("✅ MovieBattleSocketManager: Join room event emitted")
    }
    
    func disconnect() {
        let payload: [String: Any] = ["roomId": roomId]
        socket.emit(.leaveRoom, data: payload)
    }
    
    // MARK: - Handlers
    
    private func handleBattleUpdate(_ data: Data) {
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("📡 MovieBattleSocketManager: Received battle update event")
                
                if let battleData = json["battle"] as? [String: Any],
                   let battleJson = try? JSONSerialization.data(withJSONObject: battleData),
                   let battle = try? JSONDecoder().decode(MovieBattle.self, from: battleJson) {
                    print("✅ MovieBattleSocketManager: Successfully decoded battle update")
                    DispatchQueue.main.async {
                        self.onBattleUpdate?(battle)
                    }
                } else {
                    print("⚠️ MovieBattleSocketManager: Failed to decode battle from update event")
                }
            }
        } catch {
            print("❌ MovieBattleSocketManager: Failed to parse battle update: \(error)")
        }
    }
    
    private func handleMovieAdded(_ data: Data) {
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let battleData = json["battle"] as? [String: Any],
               let battleJson = try? JSONSerialization.data(withJSONObject: battleData),
               let battle = try? JSONDecoder().decode(MovieBattle.self, from: battleJson) {
                DispatchQueue.main.async {
                    self.onMovieAdded?(battle)
                }
            }
        } catch {
            print("❌ MovieBattleSocketManager: Failed to parse movie added: \(error)")
        }
    }
    
    private func handleGenerationStarted(_ data: Data) {
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let battleData = json["battle"] as? [String: Any],
               let battleJson = try? JSONSerialization.data(withJSONObject: battleData),
               let battle = try? JSONDecoder().decode(MovieBattle.self, from: battleJson) {
                DispatchQueue.main.async {
                    self.onGenerationStarted?(battle)
                }
            }
        } catch {
            print("❌ MovieBattleSocketManager: Failed to parse generation started: \(error)")
        }
    }
    
    private func handleGenerationProgress(_ data: Data) {
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("📡 MovieBattleSocketManager: Received generation progress event: \(json)")
                
                guard let movieCardId = json["movieCardId"] as? String,
                      let statusString = json["status"] as? String else {
                    print("⚠️ MovieBattleSocketManager: Missing movieCardId or status in event")
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
                
                print("📡 MovieBattleSocketManager: Parsed status: \(status.rawValue) for movieCardId: \(movieCardId)")
                
                // Пытаемся декодировать movieCard, если он есть в событии
                var movieCard: MovieCard? = nil
                if let movieCardData = json["movieCard"] as? [String: Any] {
                    print("📡 MovieBattleSocketManager: Found movieCard in event, decoding...")
                    if let movieCardJson = try? JSONSerialization.data(withJSONObject: movieCardData),
                       let decodedCard = try? JSONDecoder().decode(MovieCard.self, from: movieCardJson) {
                        movieCard = decodedCard
                        print("✅ MovieBattleSocketManager: Successfully decoded movieCard")
                    } else {
                        print("⚠️ MovieBattleSocketManager: Failed to decode movieCard")
                    }
                } else {
                    print("ℹ️ MovieBattleSocketManager: No movieCard in event")
                }
                
                DispatchQueue.main.async {
                    print("📡 MovieBattleSocketManager: Calling onGenerationProgress callback")
                    self.onGenerationProgress?(movieCardId, status, movieCard)
                }
            }
        } catch {
            print("❌ MovieBattleSocketManager: Failed to parse generation progress: \(error)")
        }
    }
    
    private func handleVotingStarted(_ data: Data) {
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let battleData = json["battle"] as? [String: Any],
               let battleJson = try? JSONSerialization.data(withJSONObject: battleData),
               let battle = try? JSONDecoder().decode(MovieBattle.self, from: battleJson) {
                DispatchQueue.main.async {
                    self.onVotingStarted?(battle)
                }
            }
        } catch {
            print("❌ MovieBattleSocketManager: Failed to parse voting started: \(error)")
        }
    }
    
    private func handleVoteCast(_ data: Data) {
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let battleData = json["battle"] as? [String: Any],
               let battleJson = try? JSONSerialization.data(withJSONObject: battleData),
               let battle = try? JSONDecoder().decode(MovieBattle.self, from: battleJson) {
                DispatchQueue.main.async {
                    self.onVoteCast?(battle)
                }
            }
        } catch {
            print("❌ MovieBattleSocketManager: Failed to parse vote cast: \(error)")
        }
    }
    
    private func handleRoundComplete(_ data: Data) {
        do {
            // Событие может прийти как массив или как объект
            let json = try JSONSerialization.jsonObject(with: data)
            
            print("📡 MovieBattleSocketManager: Received round complete event: \(json)")
            
            var battleData: [String: Any]?
            var eliminatedMovieId: String?
            var roundNumber: Int?
            var isFinished: Bool?
            
            // Проверяем, является ли это массивом
            if let jsonArray = json as? [Any], jsonArray.count >= 2 {
                print("📡 MovieBattleSocketManager: Event data is array with \(jsonArray.count) elements")
                // Первый элемент - объект battle
                if let firstElement = jsonArray[0] as? [String: Any] {
                    battleData = firstElement
                    print("✅ MovieBattleSocketManager: Extracted battle data from array[0]")
                } else {
                    print("⚠️ MovieBattleSocketManager: Array[0] is not a dictionary")
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
                    print("✅ MovieBattleSocketManager: Extracted metadata from array[1]: eliminatedMovieId=\(eliminatedMovieId ?? "nil"), roundNumber=\(roundNumber?.description ?? "nil"), isFinished=\(isFinished?.description ?? "nil")")
                } else {
                    print("⚠️ MovieBattleSocketManager: Array[1] is not a dictionary: \(jsonArray[1])")
                }
            } else if let jsonDict = json as? [String: Any] {
                print("📡 MovieBattleSocketManager: Event data is dictionary")
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
                print("⚠️ MovieBattleSocketManager: Event data is neither array nor dictionary: \(type(of: json))")
            }
            
            guard let battleData = battleData,
                  let eliminatedMovieId = eliminatedMovieId,
                  let roundNumber = roundNumber else {
                print("⚠️ MovieBattleSocketManager: Missing required fields in round complete event")
                print("   battleData: \(battleData != nil), eliminatedMovieId: \(eliminatedMovieId ?? "nil"), roundNumber: \(roundNumber?.description ?? "nil"), isFinished: \(isFinished?.description ?? "nil")")
                return
            }
            
            // isFinished уже обработан выше, но на всякий случай проверяем еще раз
            let isFinishedBool: Bool = isFinished ?? false
            
            guard let battleJson = try? JSONSerialization.data(withJSONObject: battleData) else {
                print("⚠️ MovieBattleSocketManager: Failed to serialize battle data to JSON")
                return
            }
            
            let battle: MovieBattle
            do {
                battle = try JSONDecoder().decode(MovieBattle.self, from: battleJson)
            } catch {
                print("⚠️ MovieBattleSocketManager: Failed to decode battle from round complete event: \(error)")
                if let jsonString = String(data: battleJson, encoding: .utf8) {
                    print("   Battle JSON (first 1000 chars): \(String(jsonString.prefix(1000)))")
                }
                // Пытаемся декодировать с более детальной информацией об ошибке
                if let decodingError = error as? DecodingError {
                    switch decodingError {
                    case .keyNotFound(let key, let context):
                        print("   Missing key: \(key.stringValue) at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                    case .typeMismatch(let type, let context):
                        print("   Type mismatch: expected \(type) at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                    case .valueNotFound(let type, let context):
                        print("   Value not found: \(type) at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                    case .dataCorrupted(let context):
                        print("   Data corrupted at path: \(context.codingPath.map { $0.stringValue }.joined(separator: ".")), error: \(context.debugDescription)")
                    @unknown default:
                        print("   Unknown decoding error: \(decodingError)")
                    }
                }
                return
            }
            
            print("✅ MovieBattleSocketManager: Parsed round complete - roundNumber: \(roundNumber), eliminatedMovieId: \(eliminatedMovieId), isFinished: \(isFinishedBool)")
            
            DispatchQueue.main.async {
                self.onRoundComplete?(battle, eliminatedMovieId, roundNumber, isFinishedBool)
            }
        } catch {
            print("❌ MovieBattleSocketManager: Failed to parse round complete: \(error)")
        }
    }
}


