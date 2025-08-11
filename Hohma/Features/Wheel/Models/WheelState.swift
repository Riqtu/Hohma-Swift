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

    // Callbacks
    var setEliminated: ((String) -> Void)?
    var setWheelStatus: ((WheelStatus, String) -> Void)?
    var payoutBets: ((String, String) -> Void)?

    init() {}

    func setSectors(_ newSectors: [Sector]) {
        sectors = newSectors.filter { !$0.eliminated }
        losers = newSectors.filter { $0.eliminated }
    }

    func addSector(_ sector: Sector) {
        sectors.append(sector)
    }

    func updateSector(_ sector: Sector) {
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

        spinning = true
        rotation = newRotation

        handleSpinResult(winningIndex: winningIndex, rotation: newRotation, speed: speed)

        if autoSpin {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.spinWheel()
            }
        }
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
        sectors.shuffle()
    }

    func randomColor() -> (h: Double, s: Double, l: Double) {
        let hue = Double.random(in: 0...360)
        return (h: hue, s: 60, l: 30)
    }
}
