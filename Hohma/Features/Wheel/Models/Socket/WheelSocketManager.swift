//
//  WheelSocketManager.swift
//  Hohma
//
//  Created by Artem Vydro on 06.08.2025.
//

import Foundation

// MARK: - Wheel Socket Manager
class WheelSocketManager: WheelSocketProtocol {

    // MARK: - Properties
    weak var socket: SocketIOService?
    var roomId: String?
    var clientId: String?
    private var isAuthorized = true

    // MARK: - Callbacks
    var onSpinReceived: (([String: Any]) -> Void)?
    var onShuffleReceived: (([String: Any]) -> Void)?
    var onSectorsSync: (([Sector]) -> Void)?
    var onSectorUpdated: ((Sector) -> Void)?
    var onSectorCreated: ((Sector) -> Void)?
    var onSectorRemoved: ((String) -> Void)?
    var onRoomUsersUpdated: (([AuthUser]) -> Void)?

    // MARK: - Socket Setup
    func setupSocket(_ socket: SocketIOService, roomId: String) {
        self.socket = socket
        self.roomId = roomId
        self.clientId = socket.clientId

        setupSocketEventHandlers()
    }

    func setupSocketEventHandlers() {
        guard let socket = socket else { return }

        // Handle connect event
        socket.on(.connect) { data in
            AppLogger.shared.debug("Socket connected, ready to join room", category: .socket)
        }

        // Handle wheel spin from server
        socket.on(.wheelSpin) { [weak self] data in
            AppLogger.shared.debug("Received wheelSpin event", category: .socket)
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    DispatchQueue.main.async {
                        self?.onSpinReceived?(json)
                    }
                }
            } catch {
                AppLogger.shared.error("Failed to decode spin data: \(error)", category: .socket)
            }
        }

        // Handle sectors shuffle from server
        socket.on(.sectorsShuffle) { [weak self] data in
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    DispatchQueue.main.async {
                        self?.onShuffleReceived?(json)
                    }
                }
            } catch {
                AppLogger.shared.error("Failed to decode shuffle data: \(error)", category: .socket)
            }
        }

        // Handle sectors sync
        socket.on(.syncSectors) { [weak self] data in
            do {
                let decoder = JSONDecoder()
                // WebSocket события используют timestamp формат
                decoder.dateDecodingStrategy = .secondsSince1970
                let sectors = try decoder.decode([Sector].self, from: data)
                DispatchQueue.main.async {
                    self?.onSectorsSync?(sectors)
                }
            } catch {
                AppLogger.shared.error("Failed to decode sectors data: \(error)", category: .socket)
            }
        }

        // Handle sector updates
        socket.on(.sectorUpdated) { [weak self] data in
            do {
                let decoder = JSONDecoder()
                // WebSocket события используют timestamp формат
                decoder.dateDecodingStrategy = .secondsSince1970
                let sector = try decoder.decode(Sector.self, from: data)
                DispatchQueue.main.async {
                    self?.onSectorUpdated?(sector)
                }
            } catch {
                AppLogger.shared.error("Failed to decode sector update: \(error)", category: .socket)
            }
        }

        // Handle sector creation
        socket.on(.sectorCreated) { [weak self] data in
            do {
                let decoder = JSONDecoder()
                // WebSocket события используют timestamp формат
                decoder.dateDecodingStrategy = .secondsSince1970
                let sector = try decoder.decode(Sector.self, from: data)
                DispatchQueue.main.async {
                    self?.onSectorCreated?(sector)
                }
            } catch {
                AppLogger.shared.error("Failed to decode sector creation: \(error)", category: .socket)
            }
        }

        // Handle sector removal
        socket.on(.sectorRemoved) { [weak self] data in
            do {
                let sectorId = try JSONDecoder().decode(String.self, from: data)
                DispatchQueue.main.async {
                    self?.onSectorRemoved?(sectorId)
                }
            } catch {
                AppLogger.shared.error("Failed to decode sector removal: \(error)", category: .socket)
            }
        }

        // Handle room users
        socket.on(.roomUsers) { [weak self] data in
            AppLogger.shared.debug("👥 WheelSocketManager: Received room users update", category: .socket)

            do {
                let roomUsers = try JSONDecoder().decode([RoomUser].self, from: data)
                let users = roomUsers.map { $0.toAuthUser() }

                DispatchQueue.main.async {
                    self?.onRoomUsersUpdated?(users)
                }
            } catch {
                AppLogger.shared.error("Failed to decode room users: \(error)", category: .socket)
            }
        }

        // Handle request:sectors
        socket.on(.requestSectors) { data in
            AppLogger.shared.debug("📋 WheelSocketManager: Received request:sectors", category: .socket)
            // This will be handled by the main WheelState
        }

        // Handle sync:sectors
        socket.on(.syncSectors) { data in
            AppLogger.shared.debug("📋 WheelSocketManager: Received sync:sectors", category: .socket)
            // This will be handled by the main WheelState
        }

        // Handle current:sectors
        socket.on(.currentSectors) { data in
            AppLogger.shared.debug("📋 WheelSocketManager: Received current:sectors", category: .socket)
            // This will be handled by the main WheelState
        }

        // Subscribe to socket authorization errors
        NotificationCenter.default.addObserver(
            forName: .socketAuthorizationError,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            AppLogger.shared.debug("Socket authorization error detected", category: .socket)
            self?.isAuthorized = false
        }
    }

    // MARK: - Room Management
    func joinRoom(_ roomId: String, userId: AuthUser?) {
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

        if let socket = socket, socket.isConnected, isAuthorized {
            AppLogger.shared.debug("Joining room \(roomId)", category: .socket)
            socket.emit(.joinRoom, data: joinData)
        } else {
            AppLogger.shared.warning("Cannot join room - socket not connected or not authorized", category: .socket)
        }
    }

    func leaveRoom() {
        if let roomId = roomId {
            let leaveData: [String: Any] = ["roomId": roomId]

            if let socket = socket, socket.isConnected, isAuthorized {
                socket.emit(.leaveRoom, data: leaveData)
            } else {
                print(
                    "⚠️ WheelSocketManager: Cannot leave room - socket not connected or not authorized"
                )
            }
        }
    }

    // MARK: - Sectors Synchronization
    func requestSectors() {
        AppLogger.shared.debug("📋 WheelSocketManager: Requesting sectors from other clients", category: .socket)

        if let socket = socket, socket.isConnected, isAuthorized {
            let requestData: [String: Any] = ["request": "sectors"]
            socket.emit(.requestSectors, data: requestData)
        } else {
            print(
                "⚠️ WheelSocketManager: Cannot request sectors - socket not connected or not authorized"
            )
        }
    }

    // MARK: - Server Event Handlers
    func spinWheelFromServer(_ spinData: [String: Any]) {
        AppLogger.shared.debug("Processing spin data from server", category: .socket)
        onSpinReceived?(spinData)
    }

    func shuffleSectorsFromServer(_ data: [String: Any]) {
        AppLogger.shared.debug("Processing shuffle data from server", category: .socket)
        onShuffleReceived?(data)
    }
}
