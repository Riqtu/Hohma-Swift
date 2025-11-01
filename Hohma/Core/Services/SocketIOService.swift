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
    case chatMemberOnline = "chat:member:online"
    case chatMemberOffline = "chat:member:offline"
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
    private let minReconnectInterval: TimeInterval = 2.0  // Уменьшаем минимальный интервал
    private var connectionTimeoutTimer: Timer?
    private var lastPongTime: Date?
    private let heartbeatInterval: TimeInterval = 25.0  // Синхронизируем с сервером (pingInterval)
    private let connectionTimeout: TimeInterval = 60.0  // Таймаут соединения (pingTimeout)
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
            print("🔌 SocketIOService: Already connecting, skipping...")
            return
        }

        isManualDisconnect = false
        isConnecting = true
        error = nil

        print("🔌 SocketIOService: Connecting to \(baseURL)")

        // Создаем WebSocket URL для Socket.IO
        let wsURL = baseURL.replacingOccurrences(of: "https://", with: "wss://")
        guard let url = URL(string: "\(wsURL)/socket.io/?EIO=4&transport=websocket") else {
            handleError("Invalid WebSocket URL")
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 30.0

        // Добавляем заголовки для Socket.IO
        request.setValue("websocket", forHTTPHeaderField: "Upgrade")
        request.setValue("Upgrade", forHTTPHeaderField: "Connection")
        request.setValue("13", forHTTPHeaderField: "Sec-WebSocket-Version")
        request.setValue("socket.io", forHTTPHeaderField: "Sec-WebSocket-Protocol")

        // Добавляем токен авторизации, если он есть
        if let authToken = authToken, !authToken.isEmpty {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
            #if DEBUG
                print("🔐 SocketIOService: Added authorization token to WebSocket connection")
            #endif
        } else {
            #if DEBUG
                print("🔐 SocketIOService: No authorization token provided, connecting anonymously")
            #endif
        }

        let task = session.webSocketTask(with: request)
        self.webSocket = task

        print("🔌 SocketIOService: WebSocket task created, resuming...")
        task.resume()

        // Начинаем получать сообщения
        receiveMessage()

        // Запускаем heartbeat
        startHeartbeat()

        // Проверяем состояние подключения через 5 секунд
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            guard let self = self else { return }
            if self.isConnected == false && !self.isManualDisconnect {
                print(
                    "⚠️ SocketIOService: Connection not established after 5s, attempting reconnect")
                self.handleError("Connection timeout")
            }
        }

        // Запускаем таймер таймаута соединения
        startConnectionTimeoutTimer()

        // Запускаем мониторинг здоровья соединения
        startHealthMonitoring()
    }

    func disconnect() {
        print("🔌 SocketIOService: Disconnecting...")

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

        print("🔌 SocketIOService: Disconnected successfully")
    }

    // MARK: - Event Handling
    func on(_ event: SocketIOEvent, handler: @escaping (Data) -> Void) {
        if eventHandlers[event] == nil {
            eventHandlers[event] = []
        }
        eventHandlers[event]?.append(handler)
        print("📝 SocketIOService: Registered handler for event: \(event.rawValue)")
    }

    func emit(_ event: SocketIOEvent, data: Data? = nil) {
        guard isConnected else {
            print("⚠️ SocketIOService: Cannot emit event \(event.rawValue) - not connected")
            return
        }

        print("📤 SocketIOService: Emitting event \(event.rawValue)")

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
                print("❌ SocketIOService: Failed to send message: \(error)")
                self?.handleError("Failed to send message: \(error.localizedDescription)")
            } else {
                print("✅ SocketIOService: Message sent successfully")
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
            print("🔍 SocketIOService: Detailed error info:")
            print("   - Error domain: \(error._domain)")
            print("   - Error code: \(error._code)")
            print("   - Error description: \(error.localizedDescription)")

            // Проверяем, не является ли это ошибкой отключения
            let nsError = error as NSError
            if nsError.code == 57 || nsError.domain == "NSPOSIXErrorDomain" || nsError.code == 54
                || nsError.code == 53
            {  // Дополнительные коды ошибок соединения
                print(
                    "🔌 SocketIOService: WebSocket connection lost (code: \(nsError.code), domain: \(nsError.domain)), marking as disconnected"
                )
                DispatchQueue.main.async {
                    self.isConnected = false
                    self.isConnecting = false
                }

                // Не переподключаемся, если это было ручное отключение
                if isManualDisconnect {
                    print("🔌 SocketIOService: Manual disconnect detected, skipping reconnect")
                    return
                }

                // Пытаемся переподключиться с экспоненциальной задержкой
                let delay = min(30.0, pow(2.0, Double(self.reconnectAttempts)))  // Уменьшаем максимум до 30 сек

                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    // Проверяем, прошло ли достаточно времени с последней попытки
                    if let lastReconnect = self.lastReconnectTime,
                        Date().timeIntervalSince(lastReconnect) < self.minReconnectInterval
                    {
                        print("🔄 SocketIOService: Skipping reconnect - too soon since last attempt")
                        return
                    }

                    if !self.isConnected && !self.isConnecting && !self.isManualDisconnect
                        && self.reconnectAttempts < self.maxReconnectAttempts
                    {
                        self.reconnectAttempts += 1
                        self.lastReconnectTime = Date()
                        print(
                            "🔄 SocketIOService: Attempting to reconnect after connection loss (attempt \(self.reconnectAttempts)/\(self.maxReconnectAttempts), delay: \(String(format: "%.1f", delay))s)"
                        )
                        self.connect()
                    } else if self.reconnectAttempts >= self.maxReconnectAttempts {
                        print(
                            "❌ SocketIOService: Max reconnect attempts reached, stopping reconnection"
                        )
                        // Сбрасываем счетчик через 5 минут для возможности повторных попыток
                        DispatchQueue.main.asyncAfter(deadline: .now() + 300) {
                            self.reconnectAttempts = 0
                            print(
                                "🔄 SocketIOService: Reset reconnect attempts, ready for new attempts"
                            )
                        }
                    } else {
                        print(
                            "🔄 SocketIOService: Skipping reconnect - already connected, connecting, or manual disconnect"
                        )
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
            print("⚠️ SocketIOService: Unknown message type")
        }
    }

    private func handleTextMessage(_ text: String) {
        print("📨 SocketIOService: Received text message: \(text)")

        // Обрабатываем Socket.IO сообщения
        if text.hasPrefix("0{") {
            // Socket.IO handshake
            print("🤝 SocketIOService: Processing handshake message")
            handleHandshake(text)
        } else if text.hasPrefix("40") {
            // Socket.IO connect
            print("✅ SocketIOService: Processing connect message")
            handleConnect()
        } else if text.hasPrefix("42") {
            // Socket.IO event
            print("📨 SocketIOService: Processing event message")
            handleSocketIOEvent(text)
        } else if text.hasPrefix("2") {
            // Socket.IO ping
            print("🏓 SocketIOService: Processing ping message")
            handlePing()
        } else if text.hasPrefix("3") {
            // Socket.IO pong
            print("🏓 SocketIOService: Processing pong message")
            handlePong()
        } else {
            print("❓ SocketIOService: Unknown message format: \(text)")
        }
    }

    private func handleDataMessage(_ data: Data) {
        print("📨 SocketIOService: Received data message of size: \(data.count)")

        // Try to parse as JSON and handle events
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("📨 SocketIOService: Parsed JSON: \(json)")

                if let event = json["event"] as? String,
                    let socketEvent = SocketIOEvent(rawValue: event)
                {
                    notifyEventHandlers(for: socketEvent, data: data)
                }
            }
        } catch {
            print("❌ SocketIOService: Failed to parse data message: \(error)")
        }
    }

    private func handleHandshake(_ text: String) {
        print("🤝 SocketIOService: Handling handshake: \(text)")

        // Парсим handshake данные для получения sessionId
        if let startIndex = text.firstIndex(of: "{"),
            let endIndex = text.lastIndex(of: "}")
        {
            let jsonString = String(text[startIndex...endIndex])
            if let data = jsonString.data(using: .utf8),
                let handshake = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let sid = handshake["sid"] as? String
            {
                print("🤝 SocketIOService: Session ID from handshake: \(sid)")
            }
        }

        // Отправляем connect сообщение для Socket.IO v4
        let connectMessage = "40"
        let wsMessage = URLSessionWebSocketTask.Message.string(connectMessage)
        webSocket?.send(wsMessage) { [weak self] error in
            if let error = error {
                print("❌ SocketIOService: Failed to send connect: \(error)")
                DispatchQueue.main.async {
                    self?.handleError("Failed to complete handshake: \(error.localizedDescription)")
                }
            } else {
                print("✅ SocketIOService: Connect message sent successfully")
            }
        }
    }

    private func handleConnect() {
        isConnecting = false
        isConnected = true
        reconnectAttempts = 0  // Сбрасываем счетчик попыток при успешном подключении
        lastPongTime = Date()  // Устанавливаем время последнего pong
        print("✅ SocketIOService: Connected successfully")

        // Уведомляем о подключении
        notifyEventHandlers(for: .connect, data: Data())

        // Перезапускаем heartbeat и таймеры
        startHeartbeat()
        startConnectionTimeoutTimer()

        // Добавляем небольшую задержку перед установкой готовности
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            print("🔌 SocketIOService: Connection stabilized")
        }
    }

    private func handleSocketIOEvent(_ text: String) {
        print("🔍 SocketIOService: Processing Socket.IO event: \(text)")

        // Извлекаем данные из Socket.IO сообщения
        let startIndex = text.index(text.startIndex, offsetBy: 2)
        let jsonString = String(text[startIndex...])

        print("🔍 SocketIOService: JSON string: \(jsonString)")

        guard let data = jsonString.data(using: .utf8) else {
            print("❌ SocketIOService: Failed to convert JSON string to data")
            return
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [Any] else {
            print("❌ SocketIOService: Failed to parse JSON as array")
            return
        }

        print("🔍 SocketIOService: Parsed JSON array: \(json)")

        guard json.count >= 2 else {
            print("❌ SocketIOService: JSON array has insufficient elements: \(json.count)")
            return
        }

        guard let eventName = json[0] as? String else {
            print("❌ SocketIOService: Event name is not a string: \(json[0])")
            return
        }

        // Проверяем, не является ли это событие ошибки авторизации
        if eventName == "error" || eventName == "unauthorized" {
            if let errorData = json[1] as? [String: Any],
                let message = errorData["message"] as? String
            {
                print(
                    "🔐 SocketIOService: Authorization error received: \(message), but continuing connection"
                )
                // Больше не вызываем logout, так как авторизация опциональна
                return
            }
        }

        guard let socketEvent = SocketIOEvent(rawValue: eventName) else {
            print("❌ SocketIOService: Unknown event: \(eventName)")
            return
        }

        // Извлекаем данные события
        let eventData = json[1]
        var eventDataBytes = Data()

        if let eventDataDict = eventData as? [String: Any] {
            print("🔍 SocketIOService: Event data as dict: \(eventDataDict)")

            // Проверяем, не содержит ли данные события ошибку авторизации
            if let error = eventDataDict["error"] as? String,
                error.lowercased().contains("unauthorized") || error.lowercased().contains("401")
            {
                print(
                    "🔐 SocketIOService: Authorization error in event data: \(error), but continuing connection"
                )
                // Больше не вызываем logout, так как авторизация опциональна
                return
            }

            if let data = try? JSONSerialization.data(withJSONObject: eventDataDict) {
                eventDataBytes = data
            }
        } else if let eventDataArray = eventData as? [Any] {
            print("🔍 SocketIOService: Event data as array: \(eventDataArray)")
            // Обрабатываем данные как массив (например, для room:users)
            if let data = try? JSONSerialization.data(withJSONObject: eventDataArray) {
                eventDataBytes = data
            }
        } else {
            print("🔍 SocketIOService: Event data is not a dict or array: \(eventData)")
        }

        print(
            "📨 SocketIOService: Received event: \(eventName) with data size: \(eventDataBytes.count)"
        )
        notifyEventHandlers(for: socketEvent, data: eventDataBytes)
    }

    private func handlePing() {
        // Отвечаем на ping для Socket.IO v4
        let pongMessage = "3"
        let wsMessage = URLSessionWebSocketTask.Message.string(pongMessage)
        webSocket?.send(wsMessage) { [weak self] error in
            if let error = error {
                print("❌ SocketIOService: Failed to send pong: \(error)")
                // Если не можем отправить pong, соединение проблемное
                DispatchQueue.main.async {
                    self?.handleError("Failed to respond to ping: \(error.localizedDescription)")
                }
            } else {
                print("🏓 SocketIOService: Pong sent successfully")
            }
        }
    }

    private func handlePong() {
        // Обрабатываем pong
        lastPongTime = Date()
        print("🏓 SocketIOService: Received pong at \(lastPongTime?.description ?? "unknown")")

        // Перезапускаем таймер таймаута
        startConnectionTimeoutTimer()

        // Сбрасываем счетчик попыток переподключения при успешном pong
        if reconnectAttempts > 0 {
            reconnectAttempts = 0
            print("🔄 SocketIOService: Reset reconnect attempts after successful pong")
        }
    }

    private func notifyEventHandlers(for event: SocketIOEvent, data: Data) {
        guard let handlers = eventHandlers[event] else {
            print("⚠️ SocketIOService: No handlers registered for event: \(event.rawValue)")
            return
        }

        print(
            "📨 SocketIOService: Notifying \(handlers.count) handlers for event: \(event.rawValue)")
        for handler in handlers {
            handler(data)
        }
    }

    private func handleError(_ message: String) {
        error = message
        isConnecting = false
        print("❌ SocketIOService: \(message)")

        // Проверяем, не является ли ошибка связанной с авторизацией
        if message.lowercased().contains("unauthorized") || message.lowercased().contains("401") {
            #if DEBUG
                print("🔐 SocketIOService: Authorization error detected, but continuing connection")
            #endif
            // Больше не вызываем logout, так как авторизация опциональна
            return
        }

        // Проверяем, не является ли это ошибкой отключения (код 57)
        if message.lowercased().contains("socket is not connected")
            || message.lowercased().contains("code: 57")
        {
            #if DEBUG
                print("🔌 SocketIOService: Connection lost, will attempt to reconnect")
            #endif
            // Пытаемся переподключиться через задержку, только если это не ручное отключение
            if !isManualDisconnect {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    if !self.isConnected && !self.isConnecting && !self.isManualDisconnect {
                        print("🔄 SocketIOService: Attempting to reconnect after error")
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
                print("🔄 SocketIOService: Skipping reconnect - too soon since last attempt")
                return
            }

            if !self.isConnected && !self.isConnecting && !self.isManualDisconnect
                && self.reconnectAttempts < self.maxReconnectAttempts
            {
                self.reconnectAttempts += 1
                self.lastReconnectTime = Date()
                print(
                    "🔄 SocketIOService: Attempting to reconnect... (attempt \(self.reconnectAttempts)/\(self.maxReconnectAttempts), delay: \(String(format: "%.1f", delay))s)"
                )
                self.connect()
            } else if self.reconnectAttempts >= self.maxReconnectAttempts {
                print("❌ SocketIOService: Max reconnect attempts reached, stopping reconnection")
            } else {
                print(
                    "🔄 SocketIOService: Skipping reconnect - already connected, connecting, or manual disconnect"
                )
            }
        }
    }

    private func startHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: heartbeatInterval, repeats: true) {
            [weak self] _ in
            self?.sendHeartbeat()
        }
        print("💓 SocketIOService: Heartbeat started with interval: \(heartbeatInterval)s")
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
                print("⏰ SocketIOService: Connection timeout - no pong received")
                self.handleError("Connection timeout - no heartbeat response")
            }
        }
        print("⏰ SocketIOService: Connection timeout timer started: \(connectionTimeout)s")
    }

    private func sendHeartbeat() {
        guard isConnected else {
            print("⚠️ SocketIOService: Cannot send heartbeat - not connected")
            return
        }

        let heartbeatMessage = "2"
        let wsMessage = URLSessionWebSocketTask.Message.string(heartbeatMessage)
        webSocket?.send(wsMessage) { [weak self] error in
            if let error = error {
                print("❌ SocketIOService: Failed to send heartbeat: \(error)")
                // Если не можем отправить heartbeat, соединение проблемное
                DispatchQueue.main.async {
                    self?.handleError("Failed to send heartbeat: \(error.localizedDescription)")
                }
            } else {
                print("💓 SocketIOService: Heartbeat sent successfully")
            }
        }
    }

    // MARK: - Event Emission
    func emit(_ event: SocketIOEvent, data: [String: Any]) {
        guard isConnected else {
            print("❌ SocketIOService: Cannot emit event '\(event.rawValue)' - not connected")
            return
        }

        guard let webSocket = webSocket else {
            print(
                "❌ SocketIOService: Cannot emit event '\(event.rawValue)' - no WebSocket instance")
            return
        }

        do {
            let eventData: [Any] = [event.rawValue, data]
            let jsonData = try JSONSerialization.data(withJSONObject: eventData)
            let jsonString = String(data: jsonData, encoding: .utf8) ?? ""
            let socketIOMessage = "42" + jsonString

            print("📤 SocketIOService: Emitting event '\(event.rawValue)' with data: \(data)")

            let wsMessage = URLSessionWebSocketTask.Message.string(socketIOMessage)
            webSocket.send(wsMessage) { [weak self] error in
                if let error = error {
                    print("❌ SocketIOService: Failed to emit event '\(event.rawValue)': \(error)")
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
                    print("✅ SocketIOService: Successfully emitted event '\(event.rawValue)'")
                }
            }
        } catch {
            print("❌ SocketIOService: Failed to serialize event data: \(error)")
        }
    }

    func emit(_ event: SocketIOEvent, roomId: String, data: [String: Any]) {
        guard isConnected else {
            print("❌ SocketIOService: Cannot emit event '\(event.rawValue)' - not connected")
            return
        }

        guard let webSocket = webSocket else {
            print(
                "❌ SocketIOService: Cannot emit event '\(event.rawValue)' - no WebSocket instance")
            return
        }

        do {
            let eventData: [Any] = [event.rawValue, roomId, data]
            let jsonData = try JSONSerialization.data(withJSONObject: eventData)
            let jsonString = String(data: jsonData, encoding: .utf8) ?? ""
            let socketIOMessage = "42" + jsonString

            print(
                "📤 SocketIOService: Emitting event '\(event.rawValue)' to room '\(roomId)' with data: \(data)"
            )

            let wsMessage = URLSessionWebSocketTask.Message.string(socketIOMessage)
            webSocket.send(wsMessage) { [weak self] error in
                if let error = error {
                    print("❌ SocketIOService: Failed to emit event '\(event.rawValue)': \(error)")
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
                    print(
                        "✅ SocketIOService: Successfully emitted event '\(event.rawValue)' to room '\(roomId)'"
                    )
                }
            }
        } catch {
            print("❌ SocketIOService: Failed to serialize event data: \(error)")
        }
    }

    // MARK: - Connection Management

    func resetReconnectAttempts() {
        reconnectAttempts = 0
        lastReconnectTime = nil
        print("🔄 SocketIOService: Reconnect attempts reset")
    }

    func forceReconnect() {
        print("🔄 SocketIOService: Force reconnecting...")

        // Проверяем доступность сети перед переподключением
        if !checkNetworkReachability() {
            print("⚠️ SocketIOService: Network not reachable, delaying reconnect")
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
        print("🏥 SocketIOService: Health monitoring started")
    }

    // MARK: - Connection Testing
    func testConnection() async -> Bool {
        guard let url = URL(string: baseURL) else {
            print("❌ SocketIOService: Invalid URL for connection test")
            return false
        }

        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            if let httpResponse = response as? HTTPURLResponse {
                print("🔍 SocketIOService: Server response status: \(httpResponse.statusCode)")
                return httpResponse.statusCode == 200
            }
        } catch {
            print("❌ SocketIOService: Connection test failed: \(error.localizedDescription)")
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
            print("🏥 SocketIOService: Health check skipped - not connected")
            return
        }

        // Проверяем, когда был последний pong
        if let lastPong = lastPongTime {
            let timeSinceLastPong = Date().timeIntervalSince(lastPong)
            print(
                "🏥 SocketIOService: Time since last pong: \(String(format: "%.1f", timeSinceLastPong))s"
            )

            if timeSinceLastPong > connectionTimeout {
                print("🏥 SocketIOService: Health check failed - no recent pong")
                handleError("Health check failed - connection appears dead")
            } else {
                print("🏥 SocketIOService: Health check passed")
            }
        } else {
            print("🏥 SocketIOService: Health check failed - no pong received yet")
            handleError("Health check failed - no pong received")
        }
    }

    // MARK: - Force Connection Check
    func forceConnectionCheck() {
        print("🔍 SocketIOService: Force connection check")

        if !validateConnectionState() {
            print("⚠️ SocketIOService: Connection validation failed, attempting reconnect")
            forceReconnect()
        } else {
            print("✅ SocketIOService: Connection validation passed")
        }
    }

    // MARK: - Connection State Validation
    func validateConnectionState() -> Bool {
        guard let webSocket = webSocket else {
            print("🔍 SocketIOService: No WebSocket instance")
            return false
        }

        // Проверяем состояние WebSocket
        let state = webSocket.state
        print("🔍 SocketIOService: WebSocket state: \(state.rawValue), isConnected: \(isConnected)")

        switch state {
        case .running:
            // Дополнительно проверяем, был ли недавно pong
            if let lastPong = lastPongTime {
                let timeSinceLastPong = Date().timeIntervalSince(lastPong)
                print(
                    "🔍 SocketIOService: Time since last pong: \(String(format: "%.1f", timeSinceLastPong))s"
                )
                return isConnected && timeSinceLastPong < connectionTimeout
            } else {
                print("⚠️ SocketIOService: No pong received yet")
                return isConnected
            }
        case .suspended:
            print("⚠️ SocketIOService: WebSocket is suspended")
            return false
        case .canceling:
            print("⚠️ SocketIOService: WebSocket is canceling")
            return false
        case .completed:
            print("⚠️ SocketIOService: WebSocket is completed")
            return false
        @unknown default:
            print("⚠️ SocketIOService: Unknown WebSocket state")
            return false
        }
    }

    // MARK: - Debug Info
    func printDebugInfo() {
        print("🔍 SocketIOService Debug Info:")
        print("   - Base URL: \(baseURL)")
        print("   - Client ID: \(clientId)")
        print("   - Is Connected: \(isConnected)")
        print("   - Is Connecting: \(isConnecting)")
        print("   - Error: \(error ?? "None")")
        print("   - Reconnect Attempts: \(reconnectAttempts)/\(maxReconnectAttempts)")
        print("   - Last Pong Time: \(lastPongTime?.description ?? "None")")
        print("   - WebSocket State: \(webSocket?.state.rawValue ?? -1)")
        print("   - Heartbeat Interval: \(heartbeatInterval)s")
        print("   - Connection Timeout: \(connectionTimeout)s")
    }
}
