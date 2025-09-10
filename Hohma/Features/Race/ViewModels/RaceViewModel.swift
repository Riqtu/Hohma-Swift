import Foundation
import SwiftUI

// Простая модель данных вместо View
struct RaceCellData: Identifiable {
    let id = UUID()
    let isActive: Bool
    let type: CellType

    enum CellType {
        case normal, special, finish
    }
}

class RaceViewModel: ObservableObject {
    @Published var raceCells: [RaceCellData] = []
    @Published var numberOfRoads: Int = 10

    init() {
        generateRaceCells()
    }

    private func generateRaceCells() {
        raceCells = (0..<30).map { index in
            RaceCellData(
                isActive: index == 0,  // только первая ячейка активна
                type: index == 34 ? .finish : .normal
            )
        }
    }

    func setNumberOfRoads(_ count: Int) {
        numberOfRoads = max(1, min(count, 12))
    }

    func resetRace() {
        generateRaceCells()
    }
}
