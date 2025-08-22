//
//  SocketIOServiceAdapter.swift
//  Hohma
//
//  Created by Artem Vydro on 06.08.2025.
//

import Combine
import Foundation

// MARK: - Socket.IO Service Protocol
protocol SocketIOServiceProtocol: ObservableObject {
    var isConnected: Bool { get }
    var isConnecting: Bool { get }
    var error: String? { get }
    var clientId: String { get }

    func connect()
    func disconnect()
    func on(_ event: SocketIOEvent, handler: @escaping (Data) -> Void)
    func emit(_ event: SocketIOEvent, data: [String: Any])
    func emit(_ event: SocketIOEvent, roomId: String, data: [String: Any])
    func forceReconnect()
}

// MARK: - Socket.IO Service Adapter
class SocketIOServiceAdapter: ObservableObject {
    // MARK: - Properties
    private var socketService: SocketIOServiceProtocol
    private let useNewImplementation: Bool

    // MARK: - Published Properties (delegated)
    @Published var isConnected: Bool = false
    @Published var isConnecting: Bool = false
    @Published var error: String?

    // MARK: - Public Properties
    var clientId: String {
        return socketService.clientId
    }

    // MARK: - Initialization
    init(
        baseURL: String = "https://ws.hohma.su", authToken: String? = nil,
        useNewImplementation: Bool = true
    ) {
        self.useNewImplementation = useNewImplementation

        if useNewImplementation {
            self.socketService = SocketIOServiceV2(baseURL: baseURL, authToken: authToken)
        } else {
            self.socketService = SocketIOService(baseURL: baseURL, authToken: authToken)
        }

        setupBindings()
    }

    // MARK: - Private Methods
    private func setupBindings() {
        // Привязываем свойства от внутреннего сервиса к нашим published свойствам
        if let v2Service = socketService as? SocketIOServiceV2 {
            v2Service.$isConnected
                .assign(to: &$isConnected)
            v2Service.$isConnecting
                .assign(to: &$isConnecting)
            v2Service.$error
                .assign(to: &$error)
        } else if let v1Service = socketService as? SocketIOService {
            v1Service.$isConnected
                .assign(to: &$isConnected)
            v1Service.$isConnecting
                .assign(to: &$isConnecting)
            v1Service.$error
                .assign(to: &$error)
        }
    }

    // MARK: - Public Methods (delegated)
    func connect() {
        socketService.connect()
    }

    func disconnect() {
        socketService.disconnect()
    }

    func on(_ event: SocketIOEvent, handler: @escaping (Data) -> Void) {
        socketService.on(event, handler: handler)
    }

    func emit(_ event: SocketIOEvent, data: [String: Any]) {
        socketService.emit(event, data: data)
    }

    func emit(_ event: SocketIOEvent, roomId: String, data: [String: Any]) {
        socketService.emit(event, roomId: roomId, data: data)
    }

    func forceReconnect() {
        socketService.forceReconnect()
    }

    // MARK: - Debug Methods
    func printDebugInfo() {
        print("🔍 SocketIOServiceAdapter Debug Info:")
        print("   - Using new implementation: \(useNewImplementation)")
        print("   - Is Connected: \(isConnected)")
        print("   - Is Connecting: \(isConnecting)")
        print("   - Error: \(error ?? "None")")
        print("   - Client ID: \(clientId)")

        if let v2Service = socketService as? SocketIOServiceV2 {
            v2Service.printDebugInfo()
        }
    }

    // MARK: - Implementation Info
    func getImplementationInfo() -> String {
        return useNewImplementation
            ? "Socket.IO-Client-Swift (Official)" : "Custom WebSocket Implementation"
    }
}
