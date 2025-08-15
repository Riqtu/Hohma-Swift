//
//  WheelStateProtocol.swift
//  Hohma
//
//  Created by Artem Vydro on 06.08.2025.
//

import Foundation
import SwiftUI

// MARK: - Wheel State Protocol
protocol WheelStateProtocol: ObservableObject {
    // MARK: - Published Properties
    var sectors: [Sector] { get set }
    var losers: [Sector] { get set }
    var rotation: Double { get set }
    var spinning: Bool { get set }
    var speed: Double { get set }
    var autoSpin: Bool { get set }
    var accentColor: String { get set }
    var mainColor: String { get set }
    var font: String { get set }
    var backVideo: String { get set }

    // MARK: - Callbacks
    var setEliminated: ((String) -> Void)? { get set }
    var setWheelStatus: ((WheelStatus, String) -> Void)? { get set }
    var payoutBets: ((String, String) -> Void)? { get set }

    // MARK: - Sector Management
    func setSectors(_ newSectors: [Sector])
    func addSector(_ sector: Sector)
    func updateSector(_ sector: Sector)
    func removeSector(id: String)

    // MARK: - Wheel Actions
    func spinWheel()
    func shuffleSectors()
    func randomColor() -> (h: Double, s: Double, l: Double)

    // MARK: - Cleanup
    func cleanup()
}
