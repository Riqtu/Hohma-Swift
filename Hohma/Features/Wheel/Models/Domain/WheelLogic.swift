//
//  WheelLogic.swift
//  Hohma
//
//  Created by Artem Vydro on 06.08.2025.
//

import Foundation

// MARK: - Wheel Logic Implementation
class WheelLogic: WheelLogicProtocol {

    // MARK: - Spin Logic
    func calculateSpinRotation(sectors: [Sector], currentRotation: Double, speed: Double) -> (
        rotation: Double, winningIndex: Int
    ) {
        let totalSectors = sectors.count
        let anglePerSector = 360.0 / Double(totalSectors)
        let winningIndex = Int.random(in: 0..<totalSectors)
        let sectorStartAngle = Double(winningIndex) * anglePerSector
        let targetAngle = sectorStartAngle + Double.random(in: 0..<anglePerSector)
        let currentRotation = currentRotation.truncatingRemainder(dividingBy: 360)
        var delta = -targetAngle - currentRotation
        delta = delta.truncatingRemainder(dividingBy: 360)
        if delta < 0 { delta += 360 }
        let extraSpins = 360.0 * 5
        let finalDelta = extraSpins + delta
        let newRotation = currentRotation + finalDelta

        return (rotation: newRotation, winningIndex: winningIndex)
    }

    func handleSpinResult(
        winningIndex: Int, rotation: Double, speed: Double, sectors: [Sector],
        losers: [Sector]
    ) -> (updatedSectors: [Sector], updatedLosers: [Sector]) {
        var updatedSectors = sectors
        var updatedLosers = losers

        let eliminatedSector = updatedSectors[winningIndex]
        updatedSectors.remove(at: winningIndex)
        updatedLosers.insert(eliminatedSector, at: 0)

        let remainingSectorsCount = updatedSectors.count
        let losersCount = updatedLosers.count

        DispatchQueue.main.asyncAfter(deadline: .now() + speed) {
            // Notify about elimination
            NotificationCenter.default.post(
                name: .sectorEliminated,
                object: eliminatedSector.id
            )

            // Check if game is completed
            if remainingSectorsCount == 1 && losersCount > 0 {
                NotificationCenter.default.post(
                    name: .wheelCompleted,
                    object: eliminatedSector
                )
            }
        }

        return (updatedSectors: updatedSectors, updatedLosers: updatedLosers)
    }

    // MARK: - Sector Management Logic
    func createSectorDictionary(_ sector: Sector) -> [String: Any] {
        return [
            "id": sector.id,
            "label": sector.label,
            "color": "#000000",
            "name": sector.name,
            "eliminated": sector.eliminated,
            "winner": sector.winner,
            "description": sector.description ?? "",
            "pattern": sector.pattern ?? "",
            "labelColor": sector.labelColor ?? "",
            "labelHidden": sector.labelHidden,
            "wheelId": sector.wheelId,
            "userId": sector.userId ?? "",
        ]
    }

    func createSectorsArray(_ sectors: [Sector]) -> [[String: Any]] {
        return sectors.map { createSectorDictionary($0) }
    }
}
