//
//  SocketIOServiceV2.swift
//  Hohma
//
//  Created by Artem Vydro on 06.08.2025.
//

import Combine
import Foundation
import SocketIO

// MARK: - Socket.IO Service V2 (using official Socket.IO-Client-Swift)
class SocketIOServiceV2: ObservableObject, SocketIOServiceProtocol {
    // MARK: - Properties
    private let baseURL: String
    private let _clientId = UUID().uuidString

    private var manager: SocketManager?
    private var socket: SocketIOClient?
    private var authToken: String?
    
    // Сохраняем обработчики события connect для вызова при подключении
    private var connectHandlers: [(Data) -> Void] = []

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
        setupSocketManager()
    }

    // MARK: - Socket Manager Setup
    private func setupSocketManager() {
        guard let url = URL(string: baseURL) else {
            handleError("Invalid URL: \(baseURL)")
            return
        }

        // Конфигурация Socket.IO клиента
        let config: SocketIOClientConfiguration = [
            .log(true),  // Включаем логирование для отладки
            .compress,
            .forceWebsockets(true),  // Принудительно используем WebSocket
            .reconnects(true),  // Включаем автоматическое переподключение
            .reconnectAttempts(10),  // Максимум 10 попыток переподключения
            .reconnectWait(2),  // Ждем 2 секунды между попытками
            .reconnectWaitMax(30),  // Максимум 30 секунд между попытками
            .forceNew(true),  // Принудительно создаем новое соединение
            .extraHeaders(["Authorization": "Bearer \(authToken ?? "")"]),  // Добавляем токен авторизации
            .connectParams(["EIO": "4"]),  // Указываем версию Engine.IO
        ]

        manager = SocketManager(socketURL: url, config: config)
        socket = manager?.defaultSocket

        setupEventHandlers()

        print("🔌 SocketIOServiceV2: Socket manager initialized for \(baseURL)")
    }

    // MARK: - Event Handlers Setup
    private func setupEventHandlers() {
        guard let socket = socket else { return }

        // Обработка подключения
        socket.on(clientEvent: .connect) { [weak self] data, ack in
            print("✅ SocketIOServiceV2: Connected successfully")
            print("📊 SocketIOServiceV2: Connect data: \(data)")
            DispatchQueue.main.async {
                self?.isConnected = true
                self?.isConnecting = false
                self?.error = nil
            }
            
            // Вызываем все зарегистрированные обработчики события connect
            if let self = self {
                let emptyData = Data()
                DispatchQueue.main.async {
                    for handler in self.connectHandlers {
                        handler(emptyData)
                    }
                    print("📨 SocketIOServiceV2: Called \(self.connectHandlers.count) connect handlers")
                }
            }

            // Обработчики событий регистрируются напрямую через метод on()
        }

        // Обработка отключения
        socket.on(clientEvent: .disconnect) { [weak self] data, ack in
            print("🔌 SocketIOServiceV2: Disconnected")
            DispatchQueue.main.async {
                self?.isConnected = false
                self?.isConnecting = false
            }
            // Обработчики событий теперь регистрируются напрямую через метод on()
        }

        // Обработка ошибок
        socket.on(clientEvent: .error) { [weak self] data, ack in
            if let errorData = data.first as? [String: Any],
                let message = errorData["message"] as? String
            {
                print("❌ SocketIOServiceV2: Socket error: \(message)")
                DispatchQueue.main.async {
                    self?.error = message
                }
            }
        }

        // Обработка переподключения
        socket.on(clientEvent: .reconnect) { [weak self] data, ack in
            print("🔄 SocketIOServiceV2: Reconnecting...")
            DispatchQueue.main.async {
                self?.isConnecting = true
            }
        }

        socket.on(clientEvent: .reconnectAttempt) { data, ack in
            if let attempt = data.first as? Int {
                print("🔄 SocketIOServiceV2: Reconnect attempt \(attempt)")
            }
        }

        // Обработка пользовательских событий будет происходить через метод on()
        // Регистрируем только базовые события для внутренней обработки
        print("📝 SocketIOServiceV2: Event handlers will be registered via on() method")
    }

    // MARK: - Connection Management
    func connect() {
        guard let socket = socket else {
            handleError("Socket not initialized")
            return
        }

        guard !isConnecting else {
            print("🔌 SocketIOServiceV2: Already connecting, skipping...")
            return
        }

        print("🔌 SocketIOServiceV2: Connecting to \(baseURL)")

        DispatchQueue.main.async {
            self.isConnecting = true
            self.error = nil
        }

        socket.connect()
    }

    func disconnect() {
        guard let socket = socket else { return }

        print("🔌 SocketIOServiceV2: Disconnecting...")

        DispatchQueue.main.async {
            self.isConnecting = false
            self.isConnected = false
        }

        socket.disconnect()
    }

    // MARK: - Event Handling
    func on(_ event: SocketIOEvent, handler: @escaping (Data) -> Void) {
        guard let socket = socket else {
            print("❌ SocketIOServiceV2: Cannot register handler - socket not initialized")
            return
        }

        // Специальная обработка события connect - сохраняем обработчик и вызываем его при подключении
        if event == .connect {
            print("📝 SocketIOServiceV2: Registering connect handler (will be called on clientEvent: .connect)")
            connectHandlers.append(handler)
            // Если уже подключены, вызываем обработчик сразу
            if isConnected {
                DispatchQueue.main.async {
                    handler(Data())
                }
            }
            return
        }

        // Регистрируем обработчик напрямую в сокете для других событий
        socket.on(event.rawValue) { data, ack in
            print("📨 SocketIOServiceV2: ===== Received event: \(event.rawValue) =====")
            print("📊 SocketIOServiceV2: Event data count: \(data.count)")
            print("📊 SocketIOServiceV2: Event data: \(data)")
            
            // Специальная обработка для chat:list:updated
            if event == .chatListUpdated {
                print("📨 SocketIOServiceV2: Processing chat:list:updated event")
                if let firstData = data.first {
                    print("📨 SocketIOServiceV2: First data type: \(type(of: firstData))")
                    if let dictData = firstData as? [String: Any] {
                        print("📨 SocketIOServiceV2: chat:list:updated data: \(dictData)")
                    }
                }
            }

            // Преобразуем данные в Data для совместимости
            var eventData = Data()
            if let firstData = data.first {
                // Проверяем тип данных и обрабатываем соответственно
                if let arrayData = firstData as? [Any] {
                    // Если это массив, сериализуем его
                    if let jsonData = try? JSONSerialization.data(
                        withJSONObject: arrayData, options: [])
                    {
                        eventData = jsonData
                    } else {
                        print(
                            "⚠️ SocketIOServiceV2: Could not serialize array data for event \(event.rawValue)"
                        )
                        eventData = Data()
                    }
                } else if let dictData = firstData as? [String: Any] {
                    // Если это словарь, сериализуем его
                    if let jsonData = try? JSONSerialization.data(
                        withJSONObject: dictData, options: [])
                    {
                        eventData = jsonData
                    } else {
                        print(
                            "⚠️ SocketIOServiceV2: Could not serialize dict data for event \(event.rawValue)"
                        )
                        eventData = Data()
                    }
                } else if let stringData = firstData as? String {
                    // Если это строка, конвертируем в Data
                    if let data = stringData.data(using: .utf8) {
                        eventData = data
                    } else {
                        print(
                            "⚠️ SocketIOServiceV2: Could not convert string data for event \(event.rawValue)"
                        )
                        eventData = Data()
                    }
                } else {
                    // Если не можем сериализовать, создаем пустые данные
                    print(
                        "⚠️ SocketIOServiceV2: Unknown data type for event \(event.rawValue): \(type(of: firstData))"
                    )
                    eventData = Data()
                }
            }

            // Вызываем пользовательский обработчик
            handler(eventData)
        }

        print("📝 SocketIOServiceV2: Registered handler for event: \(event.rawValue)")
    }

    // MARK: - Event Emission
    func emit(_ event: SocketIOEvent, data: [String: Any]) {
        guard let socket = socket else {
            print(
                "❌ SocketIOServiceV2: Cannot emit event '\(event.rawValue)' - socket not initialized"
            )
            return
        }

        guard isConnected else {
            print("❌ SocketIOServiceV2: Cannot emit event '\(event.rawValue)' - not connected")
            return
        }

        print("📤 SocketIOServiceV2: Emitting event '\(event.rawValue)' with data: \(data)")

        socket.emit(event.rawValue, data)
    }

    func emit(_ event: SocketIOEvent, data: [[String: Any]]) {
        guard let socket = socket else {
            print(
                "❌ SocketIOServiceV2: Cannot emit event '\(event.rawValue)' - socket not initialized"
            )
            return
        }

        guard isConnected else {
            print("❌ SocketIOServiceV2: Cannot emit event '\(event.rawValue)' - not connected")
            return
        }

        print("📤 SocketIOServiceV2: Emitting event '\(event.rawValue)' with array data: \(data)")

        socket.emit(event.rawValue, data)
    }

    func emit(_ event: SocketIOEvent, roomId: String, data: [String: Any]) {
        guard let socket = socket else {
            print(
                "❌ SocketIOServiceV2: Cannot emit event '\(event.rawValue)' - socket not initialized"
            )
            return
        }

        guard isConnected else {
            print("❌ SocketIOServiceV2: Cannot emit event '\(event.rawValue)' - not connected")
            return
        }

        // Объединяем roomId с данными для совместимости с Socket.IO-Client-Swift
        var combinedData = data
        combinedData["roomId"] = roomId

        print(
            "📤 SocketIOServiceV2: Emitting event '\(event.rawValue)' to room '\(roomId)' with data: \(combinedData)"
        )

        socket.emit(event.rawValue, combinedData)
    }

    // Новый метод для отправки событий в формате (roomId, data) как ожидает сервер
    func emitToRoom(_ event: SocketIOEvent, roomId: String, data: [String: Any]) {
        guard let socket = socket else {
            print(
                "❌ SocketIOServiceV2: Cannot emit event '\(event.rawValue)' - socket not initialized"
            )
            return
        }

        guard isConnected else {
            print("❌ SocketIOServiceV2: Cannot emit event '\(event.rawValue)' - not connected")
            return
        }

        print(
            "📤 SocketIOServiceV2: Emitting event '\(event.rawValue)' to room '\(roomId)' with data: \(data)"
        )

        // Отправляем в формате (roomId, data) как ожидает сервер
        socket.emit(event.rawValue, roomId, data)
    }

    // Перегрузка для отправки строки
    func emitToRoom(_ event: SocketIOEvent, roomId: String, data: String) {
        guard let socket = socket else {
            print(
                "❌ SocketIOServiceV2: Cannot emit event '\(event.rawValue)' - socket not initialized"
            )
            return
        }

        guard isConnected else {
            print("❌ SocketIOServiceV2: Cannot emit event '\(event.rawValue)' - not connected")
            return
        }

        print(
            "📤 SocketIOServiceV2: Emitting event '\(event.rawValue)' to room '\(roomId)' with string data: \(data)"
        )

        // Отправляем в формате (roomId, data) как ожидает сервер
        socket.emit(event.rawValue, roomId, data)
    }

    // MARK: - Private Methods

    private func handleError(_ message: String) {
        DispatchQueue.main.async {
            self.error = message
            self.isConnecting = false
        }
        print("❌ SocketIOServiceV2: \(message)")
    }

    // MARK: - Connection Management
    func forceReconnect() {
        print("🔄 SocketIOServiceV2: Force reconnecting...")
        disconnect()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.connect()
        }
    }

    // MARK: - Connection State
    func getConnectionState() -> String {
        guard let socket = socket else { return "Not Initialized" }

        switch socket.status {
        case .connected:
            return "Connected"
        case .connecting:
            return "Connecting"
        case .disconnected:
            return "Disconnected"
        case .notConnected:
            return "Not Connected"
        @unknown default:
            return "Unknown"
        }
    }

    // MARK: - Connection State Validation (for compatibility)
    func validateConnectionState() -> Bool {
        guard let socket = socket else { return false }

        // Для новой реализации просто проверяем статус сокета
        return socket.status == .connected && isConnected
    }

    // MARK: - Debug Info
    func printDebugInfo() {
        print("🔍 SocketIOServiceV2 Debug Info:")
        print("   - Base URL: \(baseURL)")
        print("   - Client ID: \(clientId)")
        print("   - Connection State: \(getConnectionState())")
        print("   - Is Connected: \(isConnected)")
        print("   - Is Connecting: \(isConnecting)")
        print("   - Error: \(error ?? "None")")
        print("   - Socket ID: \(socket?.sid ?? "None")")
        print("   - Manager Status: \(manager?.status.rawValue ?? -1)")
    }
}
