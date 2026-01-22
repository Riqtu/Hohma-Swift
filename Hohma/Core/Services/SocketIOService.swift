//
//  SocketIOService.swift
//  Hohma
//
//  Created by Artem Vydro on 06.08.2025.
//

import Combine
import Foundation

// MARK: - Notification Names
extension Notification.Name {
    static let socketAuthorizationError = Notification.Name("socketAuthorizationError")
    static let roomUsersUpdated = Notification.Name("roomUsersUpdated")
    static let deepLinkToWheel = Notification.Name("deepLinkToWheel")
    static let chatListUpdated = Notification.Name("chatListUpdated")
    static let chatBackgroundUpdated = Notification.Name("chatBackgroundUpdated")
}

// MARK: - Socket.IO Events
enum SocketIOEvent: String, CaseIterable {
    case connect = "connect"
    case disconnect = "disconnect"
    case joinRoom = "join:room"
    case leaveRoom = "leave:room"
    case wheelSpin = "wheel:spin"
    case sectorsShuffle = "sectors:shuffle"
    case syncSectors = "sync:sectors"
    case requestSectors = "request:sectors"
    case currentSectors = "current:sectors"
    case roomUsers = "room:users"
    case sectorUpdated = "sector:updated"
    case sectorCreated = "sector:created"
    case sectorRemoved = "sector:removed"
    // Race events
    case raceUpdate = "race:update"
    case raceRequestState = "race:request:state"
    case raceState = "race:state"
    case raceDiceOpen = "race:dice:open"
    case raceDiceResults = "race:dice:results"
    case raceDiceNext = "race:dice:next"
    case raceFinish = "race:finish"
    // Chat events
    case chatJoin = "chat:join"
    case chatLeave = "chat:leave"
    case chatTyping = "chat:typing"
    case chatMessage = "chat:message"
    case chatMessageUpdated = "chat:message:updated"
    case chatMessageDeleted = "chat:message:deleted"
    case chatMessageReaction = "chat:message:reaction"
    case chatMemberOnline = "chat:member:online"
    case chatMemberOffline = "chat:member:offline"
    case chatUnreadCountUpdated = "chat:unreadCount:updated"
    case chatListUpdated = "chat:list:updated"
    // User global room events
    case userJoin = "user:join"
    case userLeave = "user:leave"
    // Movie Battle events
    case movieBattleUpdate = "movieBattle:update"
    case movieBattleMovieAdded = "movieBattle:movie:added"
    case movieBattleGenerationStarted = "movieBattle:generation:started"
    case movieBattleGenerationProgress = "movieBattle:generation:progress"
    case movieBattleVotingStarted = "movieBattle:voting:started"
    case movieBattleVoteCast = "movieBattle:vote:cast"
    case movieBattleRoundComplete = "movieBattle:round:complete"
}

// MARK: - Socket.IO Data Models (Shared with WheelState)

// MARK: - Socket.IO Service
class SocketIOService: ObservableObject, SocketIOServiceProtocol {
    // MARK: - Properties
    private let baseURL: String
    private let _clientId = UUID().uuidString
    private var eventHandlers: [SocketIOEvent: [(Data) -> Void]] = [:]
    private var reconnectTimer: Timer?
    private var webSocket: URLSessionWebSocketTask?
    private let session = URLSession.shared
    private var heartbeatTimer: Timer?
    private var authToken: String?
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 10  // Уменьшаем количество попыток
    private var lastReconnectTime: Date?
    private let minReconnectInterval: TimeInterval = AppConstants.minReconnectInterval
    private var connectionTimeoutTimer: Timer?
    private var lastPongTime: Date?
    private let heartbeatInterval: TimeInterval = AppConstants.heartbeatInterval
    private let connectionTimeout: TimeInterval = AppConstants.connectionTimeout
    private var isManualDisconnect = false  // Флаг для различения ручного отключения

    // MARK: - Published Properties
    @Published var isConnected = false
    @Published var isConnecting = false
    @Published var error: String?

    // MARK: - Public Properties
    var clientId: String {
        return _clientId
    }

    // MARK: - Initialization
    init(baseURL: String? = nil, authToken: String? = nil) {
        let wsURL =
            baseURL ?? Bundle.main.object(forInfoDictionaryKey: "WS_URL") as? String
            ?? "https://ws.hohma.su"
        self.baseURL = wsURL
        self.authToken = authToken
    }

    // MARK: - Connection Management
    func connect() {
        guard !isConnecting else {
            AppLogger.shared.debug("Already connecting, skipping...", category: .socket)
            return
        }

        isManualDisconnect = false
        isConnecting = true
        error = nil

        AppLogger.shared.info("Connecting to \(baseURL)", category: .socket)

        // Создаем WebSocket URL для Socket.IO
        let wsURL = baseURL.replacingOccurrences(of: "https://", with: "wss://")
        guard let url = URL(string: "\(wsURL)/socket.io/?EIO=4&transport=websocket") else {
            handleError("Invalid WebSocket URL")
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = AppConstants.networkRequestTimeout

        // Добавляем заголовки для Socket.IO
        request.setValue("websocket", forHTTPHeaderField: "Upgrade")
        request.setValue("Upgrade", forHTTPHeaderField: "Connection")
        request.setValue("13", forHTTPHeaderField: "Sec-WebSocket-Version")
        request.setValue("socket.io", forHTTPHeaderField: "Sec-WebSocket-Protocol")

        // Добавляем токен авторизации, если он есть
        if let authToken = authToken, !authToken.isEmpty {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
            #if DEBUG
                AppLogger.shared.debug("Added authorization token to WebSocket connection", category: .socket)
            #endif
        } else {
            #if DEBUG
                AppLogger.shared.debug("No authorization token provided, connecting anonymously", category: .socket)
            #endif
        }

        let task = session.webSocketTask(with: request)
        self.webSocket = task

        AppLogger.shared.debug("WebSocket task created, resuming...", category: .socket)
        task.resume()

        // Начинаем получать сообщения
        receiveMessage()

        // Запускаем heartbeat
        startHeartbeat()

        // Проверяем состояние подключения
        DispatchQueue.main.asyncAfter(deadline: .now() + AppConstants.connectionCheckInterval) { [weak self] in
            guard let self = self else { return }
            if self.isConnected == false && !self.isManualDisconnect {
                AppLogger.shared.warning(
                    "Connection not established after 5s, attempting reconnect", category: .socket)
                self.handleError("Connection timeout")
            }
        }

        // Запускаем таймер таймаута соединения
        startConnectionTimeoutTimer()

        // Запускаем мониторинг здоровья соединения
        startHealthMonitoring()
    }

    func disconnect() {
        AppLogger.shared.info("Disconnecting...", category: .socket)

        isManualDisconnect = true
        isConnecting = false
        isConnected = false

        webSocket?.cancel()
        webSocket = nil

        heartbeatTimer?.invalidate()
        heartbeatTimer = nil

        reconnectTimer?.invalidate()
        reconnectTimer = nil

        connectionTimeoutTimer?.invalidate()
        connectionTimeoutTimer = nil

        AppLogger.shared.info("Disconnected successfully", category: .socket)
    }

    // MARK: - Event Handling
    func on(_ event: SocketIOEvent, handler: @escaping (Data) -> Void) {
        if eventHandlers[event] == nil {
            eventHandlers[event] = []
        }
        eventHandlers[event]?.append(handler)
        AppLogger.shared.debug("Registered handler for event: \(event.rawValue)", category: .socket)
    }

    func emit(_ event: SocketIOEvent, data: Data? = nil) {
        guard isConnected else {
            AppLogger.shared.warning("SocketIOService: Cannot emit event \(event.rawValue) - not connected", category: .socket)
            return
        }

        AppLogger.shared.debug("SocketIOService: Emitting event \(event.rawValue)", category: .socket)

        // Формируем Socket.IO сообщение
        var message = "42[\"\(event.rawValue)\""
        if let data = data {
            let jsonString = String(data: data, encoding: .utf8) ?? "{}"
            message += ",\(jsonString)"
        }
        message += "]"

        // Отправляем сообщение
        let wsMessage = URLSessionWebSocketTask.Message.string(message)
        webSocket?.send(wsMessage) { [weak self] error in
            if let error = error {
                AppLogger.shared.error("SocketIOService: Failed to send message", error: error, category: .socket)
                self?.handleError("Failed to send message: \(error.localizedDescription)")
            } else {
                AppLogger.shared.debug("SocketIOService: Message sent successfully", category: .socket)
            }
        }
    }

    // MARK: - Private Methods
    private func receiveMessage() {
        webSocket?.receive { [weak self] result in
            DispatchQueue.main.async {
                self?.handleReceiveResult(result)
            }
        }
    }

    private func handleReceiveResult(_ result: Result<URLSessionWebSocketTask.Message, Error>) {
        switch result {
        case .success(let message):
            handleMessage(message)
            receiveMessage()  // Continue receiving
        case .failure(let error):
            AppLogger.shared.debug("SocketIOService: Detailed error info:", category: .socket)
            AppLogger.shared.debug("   - Error domain: \(error._domain)", category: .socket)
            AppLogger.shared.debug("   - Error code: \(error._code)", category: .socket)
            AppLogger.shared.debug("   - Error description: \(error.localizedDescription)", category: .socket)

            // Проверяем, не является ли это ошибкой отключения
            let nsError = error as NSError
            if nsError.code == 57 || nsError.domain == "NSPOSIXErrorDomain" || nsError.code == 54
                || nsError.code == 53
            {  // Дополнительные коды ошибок соединения
                AppLogger.shared.info(
                    "SocketIOService: WebSocket connection lost (code: \(nsError.code), domain: \(nsError.domain)), marking as disconnected", category: .socket)
                DispatchQueue.main.async {
                    self.isConnected = false
                    self.isConnecting = false
                }

                // Не переподключаемся, если это было ручное отключение
                if isManualDisconnect {
                    AppLogger.shared.debug("SocketIOService: Manual disconnect detected, skipping reconnect", category: .socket)
                    return
                }

                // Пытаемся переподключиться с экспоненциальной задержкой
                let delay = min(AppConstants.maxReconnectDelay, pow(2.0, Double(self.reconnectAttempts)))

                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    // Проверяем, прошло ли достаточно времени с последней попытки
                    if let lastReconnect = self.lastReconnectTime,
                        Date().timeIntervalSince(lastReconnect) < self.minReconnectInterval
                    {
                        AppLogger.shared.debug("SocketIOService: Skipping reconnect - too soon since last attempt", category: .socket)
                        return
                    }

                    if !self.isConnected && !self.isConnecting && !self.isManualDisconnect
                        && self.reconnectAttempts < self.maxReconnectAttempts
                    {
                        self.reconnectAttempts += 1
                        self.lastReconnectTime = Date()
                        AppLogger.shared.info(
                            "SocketIOService: Attempting to reconnect after connection loss (attempt \(self.reconnectAttempts)/\(self.maxReconnectAttempts), delay: \(String(format: "%.1f", delay))s)", category: .socket)
                        self.connect()
                    } else if self.reconnectAttempts >= self.maxReconnectAttempts {
                        AppLogger.shared.warning(
                            "SocketIOService: Max reconnect attempts reached, stopping reconnection", category: .socket)
                        // Сбрасываем счетчик через 5 минут для возможности повторных попыток
                        DispatchQueue.main.asyncAfter(deadline: .now() + 300) {
                            self.reconnectAttempts = 0
                            AppLogger.shared.info(
                                "SocketIOService: Reset reconnect attempts, ready for new attempts", category: .socket)
                        }
                    } else {
                        AppLogger.shared.debug(
                            "SocketIOService: Skipping reconnect - already connected, connecting, or manual disconnect", category: .socket)
                    }
                }
                return
            }

            handleError("WebSocket error: \(error.localizedDescription) (Code: \(error._code))")
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            handleTextMessage(text)
        case .data(let data):
            handleDataMessage(data)
        @unknown default:
            AppLogger.shared.warning("SocketIOService: Unknown message type", category: .socket)
        }
    }

    private func handleTextMessage(_ text: String) {
        AppLogger.shared.debug("SocketIOService: Received text message: \(text)", category: .socket)

        // Обрабатываем Socket.IO сообщения
        if text.hasPrefix("0{") {
            // Socket.IO handshake
            AppLogger.shared.debug("SocketIOService: Processing handshake message", category: .socket)
            handleHandshake(text)
        } else if text.hasPrefix("40") {
            // Socket.IO connect
            AppLogger.shared.debug("SocketIOService: Processing connect message", category: .socket)
            handleConnect()
        } else if text.hasPrefix("42") {
            // Socket.IO event
            AppLogger.shared.debug("SocketIOService: Processing event message", category: .socket)
            handleSocketIOEvent(text)
        } else if text.hasPrefix("2") {
            // Socket.IO ping
            AppLogger.shared.debug("SocketIOService: Processing ping message", category: .socket)
            handlePing()
        } else if text.hasPrefix("3") {
            // Socket.IO pong
            AppLogger.shared.debug("SocketIOService: Processing pong message", category: .socket)
            handlePong()
        } else {
            AppLogger.shared.warning("SocketIOService: Unknown message format: \(text)", category: .socket)
        }
    }

    private func handleDataMessage(_ data: Data) {
        AppLogger.shared.debug("SocketIOService: Received data message of size: \(data.count)", category: .socket)

        // Try to parse as JSON and handle events
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                #if DEBUG
                AppLogger.shared.debug("SocketIOService: Parsed JSON: \(json.description)", category: .socket)
                #endif

                if let event = json["event"] as? String,
                    let socketEvent = SocketIOEvent(rawValue: event)
                {
                    notifyEventHandlers(for: socketEvent, data: data)
                }
            }
        } catch {
            AppLogger.shared.error("SocketIOService: Failed to parse data message: \(error.localizedDescription)", category: .socket)
        }
    }

    private func handleHandshake(_ text: String) {
        AppLogger.shared.debug("SocketIOService: Handling handshake: \(text)", category: .socket)

        // Парсим handshake данные для получения sessionId
        if let startIndex = text.firstIndex(of: "{"),
            let endIndex = text.lastIndex(of: "}")
        {
            let jsonString = String(text[startIndex...endIndex])
            if let data = jsonString.data(using: .utf8),
                let handshake = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let sid = handshake["sid"] as? String
            {
                AppLogger.shared.debug("SocketIOService: Session ID from handshake: \(sid)", category: .socket)
            }
        }

        // Отправляем connect сообщение для Socket.IO v4
        let connectMessage = "40"
        let wsMessage = URLSessionWebSocketTask.Message.string(connectMessage)
        webSocket?.send(wsMessage) { [weak self] error in
            if let error = error {
                AppLogger.shared.error("SocketIOService: Failed to send connect: \(error.localizedDescription)", category: .socket)
                DispatchQueue.main.async {
                    self?.handleError("Failed to complete handshake: \(error.localizedDescription)")
                }
            } else {
                AppLogger.shared.debug("SocketIOService: Connect message sent successfully", category: .socket)
            }
        }
    }

    private func handleConnect() {
        isConnecting = false
        isConnected = true
        reconnectAttempts = 0  // Сбрасываем счетчик попыток при успешном подключении
        lastPongTime = Date()  // Устанавливаем время последнего pong
        AppLogger.shared.info("SocketIOService: Connected successfully", category: .socket)

        // Уведомляем о подключении
        notifyEventHandlers(for: .connect, data: Data())

        // Перезапускаем heartbeat и таймеры
        startHeartbeat()
        startConnectionTimeoutTimer()

        // Добавляем небольшую задержку перед установкой готовности
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            AppLogger.shared.debug("SocketIOService: Connection stabilized", category: .socket)
        }
    }

    private func handleSocketIOEvent(_ text: String) {
        AppLogger.shared.debug("SocketIOService: Processing Socket.IO event: \(text)", category: .socket)

        // Извлекаем данные из Socket.IO сообщения
        let startIndex = text.index(text.startIndex, offsetBy: 2)
        let jsonString = String(text[startIndex...])

        #if DEBUG
        AppLogger.shared.debug("SocketIOService: JSON string: \(jsonString)", category: .socket)
        #endif

        guard let data = jsonString.data(using: .utf8) else {
            AppLogger.shared.error("SocketIOService: Failed to convert JSON string to data", category: .socket)
            return
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [Any] else {
            AppLogger.shared.error("SocketIOService: Failed to parse JSON as array", category: .socket)
            return
        }

        #if DEBUG
        AppLogger.shared.debug("SocketIOService: Parsed JSON array: \(json.description)", category: .socket)
        #endif

        guard json.count >= 2 else {
            AppLogger.shared.error("SocketIOService: JSON array has insufficient elements: \(json.count)", category: .socket)
            return
        }

        guard let eventName = json[0] as? String else {
            AppLogger.shared.error("SocketIOService: Event name is not a string: \(String(describing: json[0]))", category: .socket)
            return
        }

        // Проверяем, не является ли это событие ошибки авторизации
        if eventName == "error" || eventName == "unauthorized" {
            if let errorData = json[1] as? [String: Any],
                let message = errorData["message"] as? String
            {
                AppLogger.shared.warning(
                    "SocketIOService: Authorization error received: \(message), but continuing connection", category: .socket)
                // Больше не вызываем logout, так как авторизация опциональна
                return
            }
        }

        guard let socketEvent = SocketIOEvent(rawValue: eventName) else {
            AppLogger.shared.warning("SocketIOService: Unknown event: \(eventName)", category: .socket)
            return
        }

        // Извлекаем данные события
        let eventData = json[1]
        var eventDataBytes = Data()

        if let eventDataDict = eventData as? [String: Any] {
            #if DEBUG
            AppLogger.shared.debug("SocketIOService: Event data as dict: \(eventDataDict.description)", category: .socket)
            #endif

            // Проверяем, не содержит ли данные события ошибку авторизации
            if let error = eventDataDict["error"] as? String,
                error.lowercased().contains("unauthorized") || error.lowercased().contains("401")
            {
                AppLogger.shared.warning(
                    "SocketIOService: Authorization error in event data: \(error), but continuing connection", category: .socket)
                // Больше не вызываем logout, так как авторизация опциональна
                return
            }

            if let data = try? JSONSerialization.data(withJSONObject: eventDataDict) {
                eventDataBytes = data
            }
        } else if let eventDataArray = eventData as? [Any] {
            #if DEBUG
            AppLogger.shared.debug("SocketIOService: Event data as array: \(eventDataArray.description)", category: .socket)
            #endif
            // Обрабатываем данные как массив (например, для room:users)
            if let data = try? JSONSerialization.data(withJSONObject: eventDataArray) {
                eventDataBytes = data
            }
        } else {
            AppLogger.shared.debug("SocketIOService: Event data is not a dict or array: \(String(describing: eventData))", category: .socket)
        }

        AppLogger.shared.debug(
            "SocketIOService: Received event: \(eventName) with data size: \(eventDataBytes.count)", category: .socket)
        notifyEventHandlers(for: socketEvent, data: eventDataBytes)
    }

    private func handlePing() {
        // Отвечаем на ping для Socket.IO v4
        let pongMessage = "3"
        let wsMessage = URLSessionWebSocketTask.Message.string(pongMessage)
        webSocket?.send(wsMessage) { [weak self] error in
            if let error = error {
                AppLogger.shared.error("SocketIOService: Failed to send pong: \(error.localizedDescription)", category: .socket)
                // Если не можем отправить pong, соединение проблемное
                DispatchQueue.main.async {
                    self?.handleError("Failed to respond to ping: \(error.localizedDescription)")
                }
            } else {
                AppLogger.shared.debug("SocketIOService: Pong sent successfully", category: .socket)
            }
        }
    }

    private func handlePong() {
        // Обрабатываем pong
        lastPongTime = Date()
        AppLogger.shared.debug("SocketIOService: Received pong at \(lastPongTime?.description ?? "unknown")", category: .socket)

        // Перезапускаем таймер таймаута
        startConnectionTimeoutTimer()

        // Сбрасываем счетчик попыток переподключения при успешном pong
        if reconnectAttempts > 0 {
            reconnectAttempts = 0
            AppLogger.shared.info("SocketIOService: Reset reconnect attempts after successful pong", category: .socket)
        }
    }

    private func notifyEventHandlers(for event: SocketIOEvent, data: Data) {
        guard let handlers = eventHandlers[event] else {
            AppLogger.shared.warning("SocketIOService: No handlers registered for event: \(event.rawValue)", category: .socket)
            return
        }

        AppLogger.shared.debug(
            "SocketIOService: Notifying \(handlers.count) handlers for event: \(event.rawValue)", category: .socket)
        for handler in handlers {
            handler(data)
        }
    }

    private func handleError(_ message: String) {
        error = message
        isConnecting = false
        AppLogger.shared.error("SocketIOService: \(message)", category: .socket)

        // Проверяем, не является ли ошибка связанной с авторизацией
        if message.lowercased().contains("unauthorized") || message.lowercased().contains("401") {
            #if DEBUG
                AppLogger.shared.warning("SocketIOService: Authorization error detected, but continuing connection", category: .socket)
            #endif
            // Больше не вызываем logout, так как авторизация опциональна
            return
        }

        // Проверяем, не является ли это ошибкой отключения (код 57)
        if message.lowercased().contains("socket is not connected")
            || message.lowercased().contains("code: 57")
        {
            #if DEBUG
                AppLogger.shared.debug("SocketIOService: Connection lost, will attempt to reconnect", category: .socket)
            #endif
            // Пытаемся переподключиться через задержку, только если это не ручное отключение
            if !isManualDisconnect {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    if !self.isConnected && !self.isConnecting && !self.isManualDisconnect {
                        AppLogger.shared.info("SocketIOService: Attempting to reconnect after error", category: .socket)
                        self.connect()
                    }
                }
            }
            return
        }

        // Attempt to reconnect after a delay, but only if not already connected/connecting and not manual disconnect
        reconnectTimer?.invalidate()
        let delay = min(30.0, pow(2.0, Double(self.reconnectAttempts)))  // Экспоненциальная задержка

        reconnectTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) {
            [weak self] _ in
            guard let self = self else { return }

            // Проверяем, прошло ли достаточно времени с последней попытки
            if let lastReconnect = self.lastReconnectTime,
                Date().timeIntervalSince(lastReconnect) < self.minReconnectInterval
            {
                AppLogger.shared.debug("SocketIOService: Skipping reconnect - too soon since last attempt", category: .socket)
                return
            }

            if !self.isConnected && !self.isConnecting && !self.isManualDisconnect
                && self.reconnectAttempts < self.maxReconnectAttempts
            {
                self.reconnectAttempts += 1
                self.lastReconnectTime = Date()
                AppLogger.shared.info(
                    "SocketIOService: Attempting to reconnect... (attempt \(self.reconnectAttempts)/\(self.maxReconnectAttempts), delay: \(String(format: "%.1f", delay))s)", category: .socket)
                self.connect()
            } else if self.reconnectAttempts >= self.maxReconnectAttempts {
                AppLogger.shared.warning("SocketIOService: Max reconnect attempts reached, stopping reconnection", category: .socket)
            } else {
                AppLogger.shared.debug(
                    "SocketIOService: Skipping reconnect - already connected, connecting, or manual disconnect", category: .socket)
            }
        }
    }

    private func startHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: heartbeatInterval, repeats: true) {
            [weak self] _ in
            self?.sendHeartbeat()
        }
        AppLogger.shared.debug("SocketIOService: Heartbeat started with interval: \(heartbeatInterval)s", category: .socket)
    }

    private func startConnectionTimeoutTimer() {
        connectionTimeoutTimer?.invalidate()
        connectionTimeoutTimer = Timer.scheduledTimer(
            withTimeInterval: connectionTimeout, repeats: false
        ) { [weak self] _ in
            guard let self = self else { return }

            // Проверяем, получили ли мы pong за последнее время
            if let lastPong = self.lastPongTime,
                Date().timeIntervalSince(lastPong) > self.connectionTimeout
            {
                AppLogger.shared.warning("SocketIOService: Connection timeout - no pong received", category: .socket)
                self.handleError("Connection timeout - no heartbeat response")
            }
        }
        AppLogger.shared.debug("SocketIOService: Connection timeout timer started: \(connectionTimeout)s", category: .socket)
    }

    private func sendHeartbeat() {
        guard isConnected else {
            AppLogger.shared.warning("SocketIOService: Cannot send heartbeat - not connected", category: .socket)
            return
        }

        let heartbeatMessage = "2"
        let wsMessage = URLSessionWebSocketTask.Message.string(heartbeatMessage)
        webSocket?.send(wsMessage) { [weak self] error in
            if let error = error {
                AppLogger.shared.error("SocketIOService: Failed to send heartbeat: \(error.localizedDescription)", category: .socket)
                // Если не можем отправить heartbeat, соединение проблемное
                DispatchQueue.main.async {
                    self?.handleError("Failed to send heartbeat: \(error.localizedDescription)")
                }
            } else {
                AppLogger.shared.debug("SocketIOService: Heartbeat sent successfully", category: .socket)
            }
        }
    }

    // MARK: - Event Emission
    func emit(_ event: SocketIOEvent, data: [String: Any]) {
        guard isConnected else {
            AppLogger.shared.warning("SocketIOService: Cannot emit event '\(event.rawValue)' - not connected", category: .socket)
            return
        }

        guard let webSocket = webSocket else {
            AppLogger.shared.warning(
                "SocketIOService: Cannot emit event '\(event.rawValue)' - no WebSocket instance", category: .socket)
            return
        }

        do {
            let eventData: [Any] = [event.rawValue, data]
            let jsonData = try JSONSerialization.data(withJSONObject: eventData)
            let jsonString = String(data: jsonData, encoding: .utf8) ?? ""
            let socketIOMessage = "42" + jsonString

            #if DEBUG
            AppLogger.shared.debug("SocketIOService: Emitting event '\(event.rawValue)' with data: \(data.description)", category: .socket)
            #endif

            let wsMessage = URLSessionWebSocketTask.Message.string(socketIOMessage)
            webSocket.send(wsMessage) { [weak self] error in
                if let error = error {
                    AppLogger.shared.error("SocketIOService: Failed to emit event '\(event.rawValue)': \(error.localizedDescription)", category: .socket)
                    // Если ошибка связана с отключением, помечаем соединение как разорванное
                    if (error as NSError).code == 57
                        || (error as NSError).domain == "NSPOSIXErrorDomain"
                    {
                        DispatchQueue.main.async {
                            self?.isConnected = false
                            self?.handleError(
                                "WebSocket connection lost: \(error.localizedDescription)")
                        }
                    }
                } else {
                    AppLogger.shared.debug("SocketIOService: Successfully emitted event '\(event.rawValue)'", category: .socket)
                }
            }
        } catch {
            AppLogger.shared.error("SocketIOService: Failed to serialize event data: \(error.localizedDescription)", category: .socket)
        }
    }

    func emit(_ event: SocketIOEvent, roomId: String, data: [String: Any]) {
        guard isConnected else {
            AppLogger.shared.warning("SocketIOService: Cannot emit event '\(event.rawValue)' - not connected", category: .socket)
            return
        }

        guard let webSocket = webSocket else {
            AppLogger.shared.warning(
                "SocketIOService: Cannot emit event '\(event.rawValue)' - no WebSocket instance", category: .socket)
            return
        }

        do {
            let eventData: [Any] = [event.rawValue, roomId, data]
            let jsonData = try JSONSerialization.data(withJSONObject: eventData)
            let jsonString = String(data: jsonData, encoding: .utf8) ?? ""
            let socketIOMessage = "42" + jsonString

            #if DEBUG
            AppLogger.shared.debug(
                "SocketIOService: Emitting event '\(event.rawValue)' to room '\(roomId)' with data: \(data.description)", category: .socket)
            #endif

            let wsMessage = URLSessionWebSocketTask.Message.string(socketIOMessage)
            webSocket.send(wsMessage) { [weak self] error in
                if let error = error {
                    AppLogger.shared.error("SocketIOService: Failed to emit event '\(event.rawValue)': \(error.localizedDescription)", category: .socket)
                    // Если ошибка связана с отключением, помечаем соединение как разорванное
                    if (error as NSError).code == 57
                        || (error as NSError).domain == "NSPOSIXErrorDomain"
                    {
                        DispatchQueue.main.async {
                            self?.isConnected = false
                            self?.handleError(
                                "WebSocket connection lost: \(error.localizedDescription)")
                        }
                    }
                } else {
                    AppLogger.shared.debug(
                        "SocketIOService: Successfully emitted event '\(event.rawValue)' to room '\(roomId)'", category: .socket)
                }
            }
        } catch {
            AppLogger.shared.error("SocketIOService: Failed to serialize event data: \(error.localizedDescription)", category: .socket)
        }
    }

    // MARK: - Connection Management

    func resetReconnectAttempts() {
        reconnectAttempts = 0
        lastReconnectTime = nil
        AppLogger.shared.info("SocketIOService: Reconnect attempts reset", category: .socket)
    }

    func forceReconnect() {
        AppLogger.shared.info("SocketIOService: Force reconnecting...", category: .socket)

        // Проверяем доступность сети перед переподключением
        if !checkNetworkReachability() {
            AppLogger.shared.warning("SocketIOService: Network not reachable, delaying reconnect", category: .socket)
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                self.forceReconnect()
            }
            return
        }

        disconnect()
        resetReconnectAttempts()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.isManualDisconnect = false  // Сбрасываем флаг для принудительного переподключения
            self.connect()
        }
    }

    // MARK: - Periodic Health Monitoring
    func startHealthMonitoring() {
        // Запускаем периодические проверки здоровья соединения
        Timer.scheduledTimer(withTimeInterval: 120.0, repeats: true) { [weak self] _ in
            self?.performHealthCheck()
        }
        AppLogger.shared.info("SocketIOService: Health monitoring started", category: .socket)
    }

    // MARK: - Connection Testing
    func testConnection() async -> Bool {
        guard let url = URL(string: baseURL) else {
            AppLogger.shared.error("SocketIOService: Invalid URL for connection test", category: .socket)
            return false
        }

        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            if let httpResponse = response as? HTTPURLResponse {
                AppLogger.shared.debug("SocketIOService: Server response status: \(httpResponse.statusCode)", category: .socket)
                return httpResponse.statusCode == 200
            }
        } catch {
            AppLogger.shared.error("SocketIOService: Connection test failed: \(error.localizedDescription)", category: .socket)
        }

        return false
    }

    // MARK: - Network Monitoring
    func checkNetworkReachability() -> Bool {
        // Простая проверка доступности сети
        guard let url = URL(string: "https://www.apple.com") else { return false }

        let semaphore = DispatchSemaphore(value: 0)
        var isReachable = false

        URLSession.shared.dataTask(with: url) { _, response, error in
            if let httpResponse = response as? HTTPURLResponse {
                isReachable = httpResponse.statusCode == 200
            }
            semaphore.signal()
        }.resume()

        _ = semaphore.wait(timeout: .now() + 5.0)
        return isReachable
    }

    // MARK: - Connection Health Check
    func performHealthCheck() {
        guard isConnected else {
            AppLogger.shared.debug("SocketIOService: Health check skipped - not connected", category: .socket)
            return
        }

        // Проверяем, когда был последний pong
        if let lastPong = lastPongTime {
            let timeSinceLastPong = Date().timeIntervalSince(lastPong)
            AppLogger.shared.debug(
                "SocketIOService: Time since last pong: \(String(format: "%.1f", timeSinceLastPong))s", category: .socket)

            if timeSinceLastPong > connectionTimeout {
                AppLogger.shared.warning("SocketIOService: Health check failed - no recent pong", category: .socket)
                handleError("Health check failed - connection appears dead")
            } else {
                AppLogger.shared.debug("SocketIOService: Health check passed", category: .socket)
            }
        } else {
            AppLogger.shared.warning("SocketIOService: Health check failed - no pong received yet", category: .socket)
            handleError("Health check failed - no pong received")
        }
    }

    // MARK: - Force Connection Check
    func forceConnectionCheck() {
        AppLogger.shared.debug("SocketIOService: Force connection check", category: .socket)

        if !validateConnectionState() {
            AppLogger.shared.warning("SocketIOService: Connection validation failed, attempting reconnect", category: .socket)
            forceReconnect()
        } else {
            AppLogger.shared.debug("SocketIOService: Connection validation passed", category: .socket)
        }
    }

    // MARK: - Connection State Validation
    func validateConnectionState() -> Bool {
        guard let webSocket = webSocket else {
            AppLogger.shared.debug("SocketIOService: No WebSocket instance", category: .socket)
            return false
        }

        // Проверяем состояние WebSocket
        let state = webSocket.state
        AppLogger.shared.debug("SocketIOService: WebSocket state: \(state.rawValue), isConnected: \(isConnected)", category: .socket)

        switch state {
        case .running:
            // Дополнительно проверяем, был ли недавно pong
            if let lastPong = lastPongTime {
                let timeSinceLastPong = Date().timeIntervalSince(lastPong)
                AppLogger.shared.debug(
                    "SocketIOService: Time since last pong: \(String(format: "%.1f", timeSinceLastPong))s", category: .socket)
                return isConnected && timeSinceLastPong < connectionTimeout
            } else {
                AppLogger.shared.warning("SocketIOService: No pong received yet", category: .socket)
                return isConnected
            }
        case .suspended:
            AppLogger.shared.warning("SocketIOService: WebSocket is suspended", category: .socket)
            return false
        case .canceling:
            AppLogger.shared.warning("SocketIOService: WebSocket is canceling", category: .socket)
            return false
        case .completed:
            AppLogger.shared.warning("SocketIOService: WebSocket is completed", category: .socket)
            return false
        @unknown default:
            AppLogger.shared.warning("SocketIOService: Unknown WebSocket state", category: .socket)
            return false
        }
    }

    // MARK: - Debug Info
    func printDebugInfo() {
        AppLogger.shared.debug("SocketIOService Debug Info:", category: .socket)
        AppLogger.shared.debug("   - Base URL: \(baseURL)", category: .socket)
        AppLogger.shared.debug("   - Client ID: \(clientId)", category: .socket)
        AppLogger.shared.debug("   - Is Connected: \(isConnected)", category: .socket)
        AppLogger.shared.debug("   - Is Connecting: \(isConnecting)", category: .socket)
        AppLogger.shared.debug("   - Error: \(error ?? "None")", category: .socket)
        AppLogger.shared.debug("   - Reconnect Attempts: \(reconnectAttempts)/\(maxReconnectAttempts)", category: .socket)
        AppLogger.shared.debug("   - Last Pong Time: \(lastPongTime?.description ?? "None")", category: .socket)
        AppLogger.shared.debug("   - WebSocket State: \(webSocket?.state.rawValue ?? -1)", category: .socket)
        AppLogger.shared.debug("   - Heartbeat Interval: \(heartbeatInterval)s", category: .socket)
        AppLogger.shared.debug("   - Connection Timeout: \(connectionTimeout)s", category: .socket)
    }
}
