import Inject
import SwiftUI

struct RaceSceneView: View {
    @ObserveInjection var inject
    @StateObject private var viewModel = RaceViewModel()

    var body: some View {
        VStack {
            Image("SceneBackground")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()
                .frame(maxWidth: .infinity, minHeight: 0, maxHeight: 140)

            ScrollView(.horizontal, showsIndicators: false) {
                ZStack {
                    Image("SceneRace")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .ignoresSafeArea()
                        .padding(.horizontal, -250)

                    LazyVStack(spacing: 10) {
                        ForEach(0..<viewModel.numberOfRoads, id: \.self) { roadIndex in
                            RaceRoadView(cells: viewModel.raceCells)
                                .id("road_\(roadIndex)")
                        }
                    }
                    .padding(.top, -40)
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            // .clipped()
            .padding(.top, -50)
        }
        .enableInjection()
    }
}

#Preview {
    RaceSceneView()
}
