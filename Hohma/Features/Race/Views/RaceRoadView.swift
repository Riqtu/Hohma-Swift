import Inject
import SwiftUI

struct RaceRoadView: View {
    @ObserveInjection var inject
    let cells: [RaceCellData]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 0) {
                ForEach(cells) { cellData in
                    RaceCellView(cellData: cellData)
                }
            }
            .padding(.horizontal, 10)
        }
        .frame(height: 30)
        .enableInjection()
    }
}

#Preview {
    let raceCells = (0..<35).map { index in
        RaceCellData(isActive: index == 0, type: .normal)
    }
    RaceRoadView(cells: raceCells)
}
