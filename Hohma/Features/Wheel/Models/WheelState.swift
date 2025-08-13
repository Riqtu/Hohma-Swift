//
//  WheelState.swift
//  Hohma
//
//  Created by Artem Vydro on 06.08.2025.
//

import Foundation
import SwiftUI

@MainActor
class WheelState: ObservableObject {
    @Published var sectors: [Sector] = []
    @Published var losers: [Sector] = []
    @Published var rotation: Double = 0
    @Published var spinning: Bool = false
    @Published var speed: Double = 10
    @Published var autoSpin: Bool = false
    @Published var accentColor: String = "#F8D568"
    @Published var mainColor: String = "rgba(22, 36, 86, 0.3)"
    @Published var font: String = "pacifico"
    @Published var backVideo: String = "/themeVideo/CLASSIC.mp4"

    // Socket.IO properties
    var socket: SocketIOService?
    var roomId: String?
    var clientId: String?

    // Callbacks
    var setEliminated: ((String) -> Void)?
    var setWheelStatus: ((WheelStatus, String) -> Void)?
    var payoutBets: ((String, String) -> Void)?

    init() {}

    func setSectors(_ newSectors: [Sector]) {
        print("🔄 WheelState: Setting \(newSectors.count) sectors from server")
        sectors = newSectors.filter { !$0.eliminated }
        losers = newSectors.filter { $0.eliminated }
    }

    func addSector(_ sector: Sector) {
        print("➕ WheelState: Adding sector \(sector.label) from server")
        sectors.append(sector)
    }

    func updateSector(_ sector: Sector) {
        print("✏️ WheelState: Updating sector \(sector.label) from server")
        if !sector.eliminated {
            sectors = sectors.filter { $0.id != sector.id }
            losers = losers.filter { $0.id != sector.id }
            sectors.append(sector)
        } else {
            sectors = sectors.filter { $0.id != sector.id }
            losers = losers.filter { $0.id != sector.id }
            losers.append(sector)
        }
    }

    func removeSector(id: String) {
        print("🗑️ WheelState: Removing sector \(id) from server")
        sectors = sectors.filter { $0.id != id }
    }

    func spinWheel() {
        guard !spinning && sectors.count > 1 else { return }

        let totalSectors = sectors.count
        let anglePerSector = 360.0 / Double(totalSectors)
        let winningIndex = Int.random(in: 0..<totalSectors)
        let sectorStartAngle = Double(winningIndex) * anglePerSector
        let targetAngle = sectorStartAngle + Double.random(in: 0..<anglePerSector)
        let currentRotation = rotation.truncatingRemainder(dividingBy: 360)
        var delta = -targetAngle - currentRotation
        delta = delta.truncatingRemainder(dividingBy: 360)
        if delta < 0 { delta += 360 }
        let extraSpins = 360.0 * 5
        let finalDelta = extraSpins + delta
        let newRotation = rotation + finalDelta

        // Emit spin event to other clients
        let spinData: [String: Any] = [
            "rotation": newRotation,
            "speed": speed,
            "winningIndex": winningIndex,
            "senderClientId": clientId ?? "",
        ]
        socket?.emit(.wheelSpin, data: spinData)

        spinning = true
        rotation = newRotation

        handleSpinResult(winningIndex: winningIndex, rotation: newRotation, speed: speed)

        if autoSpin {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.spinWheel()
            }
        }
    }

    func spinWheelFromServer(_ spinData: [String: Any]) {
        print("🔄 WheelState: Processing spin data: \(spinData)")

        guard let senderClientId = spinData["senderClientId"] as? String else {
            print("❌ WheelState: Missing or invalid senderClientId in spin data")
            return
        }

        guard let rotation = spinData["rotation"] as? Double else {
            print("❌ WheelState: Missing or invalid rotation in spin data")
            return
        }

        guard let speed = spinData["speed"] as? Double else {
            print("❌ WheelState: Missing or invalid speed in spin data")
            return
        }

        guard let winningIndex = spinData["winningIndex"] as? Int else {
            print("❌ WheelState: Missing or invalid winningIndex in spin data")
            return
        }

        // Ignore if this event was initiated by this client
        if senderClientId == clientId {
            print("Ignoring spin event initiated by this client")
            return
        }

        print(
            "Received spin event from server: rotation=\(rotation), speed=\(speed), winningIndex=\(winningIndex)"
        )
        spinning = true
        self.rotation = rotation
        handleSpinResult(winningIndex: winningIndex, rotation: rotation, speed: speed)
    }

    private func handleSpinResult(winningIndex: Int, rotation: Double, speed: Double) {
        DispatchQueue.main.asyncAfter(deadline: .now() + speed) {
            let eliminatedSector = self.sectors[winningIndex]

            self.sectors.remove(at: winningIndex)
            self.losers.insert(eliminatedSector, at: 0)

            if self.sectors.count == 1 && self.losers.count > 0 {
                self.setWheelStatus?(.completed, self.sectors[0].wheelId)
                self.payoutBets?(self.sectors[0].wheelId, self.sectors[0].id)
            } else {
                self.setWheelStatus?(.active, self.sectors[0].wheelId)
            }

            self.rotation = rotation.truncatingRemainder(dividingBy: 360)
            self.spinning = false

            self.setEliminated?(eliminatedSector.id)
        }
    }

    func shuffleSectors() {
        let shuffledSectors = sectors.shuffled()

        // Emit shuffle event to other clients
        let shuffleData: [String: Any] = [
            "sectors": shuffledSectors.map { sector in
                [
                    "id": sector.id,
                    "label": sector.label,
                    "color": "#000000",
                    "name": sector.name,
                    "eliminated": sector.eliminated,
                    "winner": sector.winner,
                    "description": sector.description,
                    "pattern": sector.pattern ?? "",
                    "labelColor": sector.labelColor ?? "",
                    "labelHidden": sector.labelHidden,
                    "wheelId": sector.wheelId,
                    "userId": sector.userId,
                ]
            },
            "senderClientId": clientId ?? "",
        ]
        socket?.emit(.sectorsShuffle, data: shuffleData)

        sectors = shuffledSectors
    }

    func shuffleSectorsFromServer(_ data: [String: Any]) {
        guard let senderClientId = data["senderClientId"] as? String,
            let sectorsData = data["sectors"] as? [[String: Any]]
        else {
            print("Invalid shuffle data received")
            return
        }

        // Only update if the event came from another client
        if senderClientId != clientId {
            // For now, just log the received data
            print("Received shuffle data from server: \(sectorsData.count) sectors")
            // TODO: Implement proper sector creation from dictionary
        }
    }

    func randomColor() -> (h: Double, s: Double, l: Double) {
        let hue = Double.random(in: 0...360)
        return (h: hue, s: 60, l: 30)
    }

    // MARK: - Socket Integration

    func setupSocket(_ socket: SocketIOService, roomId: String) {
        self.socket = socket
        self.roomId = roomId
        self.clientId = socket.clientId

        setupSocketEventHandlers()
    }

    private func setupSocketEventHandlers() {
        guard let socket = socket else { return }

        // Handle wheel spin from server
        socket.on(.wheelSpin) { [weak self] data in
            print(
                "🔄 WheelState: Received wheelSpin event with data: \(String(data: data, encoding: .utf8) ?? "invalid")"
            )
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("🔄 WheelState: Parsed JSON: \(json)")
                    DispatchQueue.main.async {
                        self?.spinWheelFromServer(json)
                    }
                } else {
                    print("❌ WheelState: Failed to parse JSON from spin data")
                }
            } catch {
                print("❌ WheelState: Failed to decode spin data: \(error)")
                print("❌ WheelState: Raw data: \(String(data: data, encoding: .utf8) ?? "invalid")")
            }
        }

        // Handle sectors shuffle from server
        socket.on(.sectorsShuffle) { [weak self] data in
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    DispatchQueue.main.async {
                        self?.shuffleSectorsFromServer(json)
                    }
                }
            } catch {
                print("Failed to decode shuffle data: \(error)")
            }
        }

        // Handle sectors sync
        socket.on(.syncSectors) { [weak self] data in
            do {
                let sectors = try JSONDecoder().decode([Sector].self, from: data)
                DispatchQueue.main.async {
                    self?.setSectors(sectors)
                }
            } catch {
                print("Failed to decode sectors data: \(error)")
            }
        }

        // Handle sector updates
        socket.on(.sectorUpdated) { [weak self] data in
            do {
                let sector = try JSONDecoder().decode(Sector.self, from: data)
                DispatchQueue.main.async {
                    self?.updateSector(sector)
                }
            } catch {
                print("Failed to decode sector update: \(error)")
            }
        }

        // Handle sector creation
        socket.on(.sectorCreated) { [weak self] data in
            do {
                let sector = try JSONDecoder().decode(Sector.self, from: data)
                DispatchQueue.main.async {
                    self?.addSector(sector)
                }
            } catch {
                print("Failed to decode sector creation: \(error)")
            }
        }

        // Handle sector removal
        socket.on(.sectorRemoved) { [weak self] data in
            do {
                let sectorId = try JSONDecoder().decode(String.self, from: data)
                DispatchQueue.main.async {
                    self?.removeSector(id: sectorId)
                }
            } catch {
                print("Failed to decode sector removal: \(error)")
            }
        }
    }

    func joinRoom(_ roomId: String, userId: AuthUser?) {
        let joinData: [String: Any] = [
            "roomId": roomId,
            "clientId": clientId ?? "",
        ]
        socket?.emit(.joinRoom, data: joinData)
    }

    func leaveRoom() {
        if let roomId = roomId {
            let leaveData: [String: Any] = ["roomId": roomId]
            socket?.emit(.leaveRoom, data: leaveData)
        }
    }

    func cleanup() {
        leaveRoom()
        socket = nil
        roomId = nil
        clientId = nil
    }
}
