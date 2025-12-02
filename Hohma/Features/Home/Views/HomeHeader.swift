import Inject
import SwiftUI

struct HomeHeader: View {
    private static let headerHeight: CGFloat = 100
    let onStatsTap: (() -> Void)?
    @ObserveInjection var inject

    var body: some View {
        ZStack {
            VStack {
                Text("XOXMA")
                    .font(.custom("Luckiest Guy", size: 40))
                    .padding(.top, 20)
            }
            .frame(height: Self.headerHeight)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 25)

            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        onStatsTap?()
                    }) {
                        Image(systemName: "chart.bar.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.primary)
                            .frame(width: 50, height: 50)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.15), radius: 24, x: 0, y: 12)
                            .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
                    }
                }
            }
            .frame(height: Self.headerHeight)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 25)
        }
        .frame(height: Self.headerHeight)
        .enableInjection()
    }
}

#Preview {
    HomeHeader(onStatsTap: nil)
}
