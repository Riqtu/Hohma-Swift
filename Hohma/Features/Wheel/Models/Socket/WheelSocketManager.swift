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
            print("🔌 WheelSocketManager: Socket connected, ready to join room")
        }

        // Handle wheel spin from server
        socket.on(.wheelSpin) { [weak self] data in
            print("🔄 WheelSocketManager: Received wheelSpin event")
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    DispatchQueue.main.async {
                        self?.onSpinReceived?(json)
                    }
                }
            } catch {
                print("❌ WheelSocketManager: Failed to decode spin data: \(error)")
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
                print("❌ WheelSocketManager: Failed to decode shuffle data: \(error)")
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
                print("❌ WheelSocketManager: Failed to decode sectors data: \(error)")
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
                print("❌ WheelSocketManager: Failed to decode sector update: \(error)")
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
                print("❌ WheelSocketManager: Failed to decode sector creation: \(error)")
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
                print("❌ WheelSocketManager: Failed to decode sector removal: \(error)")
            }
        }

        // Handle room users
        socket.on(.roomUsers) { [weak self] data in
            print("👥 WheelSocketManager: Received room users update")

            do {
                let roomUsers = try JSONDecoder().decode([RoomUser].self, from: data)
                let users = roomUsers.map { $0.toAuthUser() }

                DispatchQueue.main.async {
                    self?.onRoomUsersUpdated?(users)
                }
            } catch {
                print("❌ WheelSocketManager: Failed to decode room users: \(error)")
            }
        }

        // Handle request:sectors
        socket.on(.requestSectors) { data in
            print("📋 WheelSocketManager: Received request:sectors")
            // This will be handled by the main WheelState
        }

        // Handle sync:sectors
        socket.on(.syncSectors) { data in
            print("📋 WheelSocketManager: Received sync:sectors")
            // This will be handled by the main WheelState
        }

        // Handle current:sectors
        socket.on(.currentSectors) { data in
            print("📋 WheelSocketManager: Received current:sectors")
            // This will be handled by the main WheelState
        }

        // Subscribe to socket authorization errors
        NotificationCenter.default.addObserver(
            forName: .socketAuthorizationError,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("🔐 WheelSocketManager: Socket authorization error detected")
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
            print("🔌 WheelSocketManager: Joining room \(roomId)")
            socket.emit(.joinRoom, data: joinData)
        } else {
            print("⚠️ WheelSocketManager: Cannot join room - socket not connected or not authorized")
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
        print("📋 WheelSocketManager: Requesting sectors from other clients")

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
        print("🔄 WheelSocketManager: Processing spin data from server")
        onSpinReceived?(spinData)
    }

    func shuffleSectorsFromServer(_ data: [String: Any]) {
        print("🔄 WheelSocketManager: Processing shuffle data from server")
        onShuffleReceived?(data)
    }
}
