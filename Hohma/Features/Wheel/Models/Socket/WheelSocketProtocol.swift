//
//  WheelSocketProtocol.swift
//  Hohma
//
//  Created by Artem Vydro on 06.08.2025.
//

import Foundation

// MARK: - Wheel Socket Protocol
protocol WheelSocketProtocol {
    // MARK: - Socket Setup
    func setupSocket(_ socket: SocketIOService, roomId: String)
    func setupSocketEventHandlers()

    // MARK: - Room Management
    func joinRoom(_ roomId: String, userId: AuthUser?)
    func leaveRoom()

    // MARK: - Sectors Synchronization
    func requestSectors()

    // MARK: - Server Event Handlers
    func spinWheelFromServer(_ spinData: [String: Any])
    func shuffleSectorsFromServer(_ data: [String: Any])
}
