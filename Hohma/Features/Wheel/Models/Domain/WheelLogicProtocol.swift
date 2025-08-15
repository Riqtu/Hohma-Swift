//
//  WheelLogicProtocol.swift
//  Hohma
//
//  Created by Artem Vydro on 06.08.2025.
//

import Foundation

// MARK: - Wheel Logic Protocol
protocol WheelLogicProtocol {
    // MARK: - Spin Logic
    func calculateSpinRotation(sectors: [Sector], currentRotation: Double, speed: Double) -> (
        rotation: Double, winningIndex: Int
    )
    func handleSpinResult(
        winningIndex: Int, rotation: Double, speed: Double, sectors: [Sector],
        losers: [Sector]
    ) -> (updatedSectors: [Sector], updatedLosers: [Sector])

    // MARK: - Sector Management Logic
    func createSectorDictionary(_ sector: Sector) -> [String: Any]
    func createSectorsArray(_ sectors: [Sector]) -> [[String: Any]]
}
