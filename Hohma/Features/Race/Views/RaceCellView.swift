import Inject
import SwiftUI

struct RaceCellView: View {
    @ObserveInjection var inject
    let cellData: RaceCellData

    var body: some View {
        Rectangle()
            .fill(cellData.isActive ? .green : .black.opacity(0.1))
            .frame(width: 25, height: 25)
            .cornerRadius(5)
            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
            .padding(5)
            .padding(.horizontal, 5)
            .enableInjection()
    }
}

#Preview {
    RaceCellView(cellData: RaceCellData(isActive: true, type: .normal))
}
