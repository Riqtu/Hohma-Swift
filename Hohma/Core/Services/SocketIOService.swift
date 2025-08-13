//
//  SocketIOService.swift
//  Hohma
//
//  Created by Artem Vydro on 06.08.2025.
//

import Combine
import Foundation

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
}

// MARK: - Socket.IO Data Models (Shared with WheelState)

// MARK: - Socket.IO Service
class SocketIOService: ObservableObject {
    // MARK: - Properties
    private let baseURL: String
    private let _clientId = UUID().uuidString
    private var eventHandlers: [SocketIOEvent: [(Data) -> Void]] = [:]
    private var reconnectTimer: Timer?
    private var webSocket: URLSessionWebSocketTask?
    private let session = URLSession.shared
    private var heartbeatTimer: Timer?

    // MARK: - Published Properties
    @Published var isConnected = false
    @Published var isConnecting = false
    @Published var error: String?

    // MARK: - Public Properties
    var clientId: String {
        return _clientId
    }

    // MARK: - Initialization
    init(baseURL: String = "https://ws.hohma.su") {
        self.baseURL = baseURL
    }

    // MARK: - Connection Management
    func connect() {
        guard !isConnecting else { return }

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

        let task = session.webSocketTask(with: request)
        self.webSocket = task

        print("🔌 SocketIOService: WebSocket task created, resuming...")
        task.resume()

        // Начинаем получать сообщения
        receiveMessage()

        // Запускаем heartbeat
        startHeartbeat()

        // Проверяем состояние подключения через 2 секунды
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            if self?.isConnected == false {
                print("⚠️ SocketIOService: Connection not established after 2s")
            }
        }
    }

    func disconnect() {
        isConnecting = false
        isConnected = false
        print("🔌 SocketIOService: Disconnected")

        webSocket?.cancel()
        webSocket = nil

        heartbeatTimer?.invalidate()
        heartbeatTimer = nil

        reconnectTimer?.invalidate()
        reconnectTimer = nil
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
            handleHandshake(text)
        } else if text.hasPrefix("40") {
            // Socket.IO connect
            handleConnect()
        } else if text.hasPrefix("42") {
            // Socket.IO event
            handleSocketIOEvent(text)
        } else if text.hasPrefix("2") {
            // Socket.IO ping
            handlePing()
        } else if text.hasPrefix("3") {
            // Socket.IO pong
            handlePong()
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
        print("🤝 SocketIOService: Handling handshake")
        // Отправляем connect сообщение
        let connectMessage = "40"
        let wsMessage = URLSessionWebSocketTask.Message.string(connectMessage)
        webSocket?.send(wsMessage) { [weak self] error in
            if let error = error {
                print("❌ SocketIOService: Failed to send connect: \(error)")
            }
        }
    }

    private func handleConnect() {
        isConnecting = false
        isConnected = true
        print("✅ SocketIOService: Connected successfully")

        // Уведомляем о подключении
        notifyEventHandlers(for: .connect, data: Data())
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

        guard let socketEvent = SocketIOEvent(rawValue: eventName) else {
            print("❌ SocketIOService: Unknown event: \(eventName)")
            return
        }

        // Извлекаем данные события
        let eventData = json[1]
        var eventDataBytes = Data()

        if let eventDataDict = eventData as? [String: Any] {
            print("🔍 SocketIOService: Event data as dict: \(eventDataDict)")
            if let data = try? JSONSerialization.data(withJSONObject: eventDataDict) {
                eventDataBytes = data
            }
        } else {
            print("🔍 SocketIOService: Event data is not a dict: \(eventData)")
        }

        print(
            "📨 SocketIOService: Received event: \(eventName) with data size: \(eventDataBytes.count)"
        )
        notifyEventHandlers(for: socketEvent, data: eventDataBytes)
    }

    private func handlePing() {
        // Отвечаем на ping
        let pongMessage = "3"
        let wsMessage = URLSessionWebSocketTask.Message.string(pongMessage)
        webSocket?.send(wsMessage) { error in
            if let error = error {
                print("❌ SocketIOService: Failed to send pong: \(error)")
            }
        }
    }

    private func handlePong() {
        // Обрабатываем pong
        print("🏓 SocketIOService: Received pong")
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

        // Attempt to reconnect after a delay
        reconnectTimer?.invalidate()
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) {
            [weak self] _ in
            print("🔄 SocketIOService: Attempting to reconnect...")
            self?.connect()
        }
    }

    private func startHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 25, repeats: true) {
            [weak self] _ in
            self?.sendHeartbeat()
        }
    }

    private func sendHeartbeat() {
        guard isConnected else { return }

        let heartbeatMessage = "2"
        let wsMessage = URLSessionWebSocketTask.Message.string(heartbeatMessage)
        webSocket?.send(wsMessage) { error in
            if let error = error {
                print("❌ SocketIOService: Failed to send heartbeat: \(error)")
            }
        }
    }

    // MARK: - Event Emission
    func emit(_ event: SocketIOEvent, data: [String: Any]) {
        guard isConnected else {
            print("❌ SocketIOService: Cannot emit event - not connected")
            return
        }

        do {
            let eventData: [Any] = [event.rawValue, data]
            let jsonData = try JSONSerialization.data(withJSONObject: eventData)
            let jsonString = String(data: jsonData, encoding: .utf8) ?? ""
            let socketIOMessage = "42" + jsonString

            print("📤 SocketIOService: Emitting event '\(event.rawValue)' with data: \(data)")

            let wsMessage = URLSessionWebSocketTask.Message.string(socketIOMessage)
            webSocket?.send(wsMessage) { error in
                if let error = error {
                    print("❌ SocketIOService: Failed to emit event '\(event.rawValue)': \(error)")
                } else {
                    print("✅ SocketIOService: Successfully emitted event '\(event.rawValue)'")
                }
            }
        } catch {
            print("❌ SocketIOService: Failed to serialize event data: \(error)")
        }
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
}
