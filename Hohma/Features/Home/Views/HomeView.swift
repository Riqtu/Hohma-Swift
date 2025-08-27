import Inject
import SwiftUI

struct HomeView: View {
    @ObserveInjection var inject
    @StateObject private var videoManager = VideoPlayerManager.shared
    @Environment(\.scenePhase) private var scenePhase

    // Массив карточек (чтобы было удобно генерировать)
    let cards: [CardData] = [
        CardData(
            title: "Колесо фильмов",
            description:
                "Это развлекательный сервис, который помогает выбрать, какой фильм посмотреть. Просто нажми на кнопку, и колесо случайным образом выберет фильм из разных жанров, эпох и стран. Это отличный способ избавиться от мук выбора и открыть для себя новые киноленты!",
            imageName: "testImage",
            videoName: "movie"
        ),
        CardData(
            title: "ХОХМА.ДОСЬЕ",
            description:
                "Добро пожаловать в ХОХМА.ДОСЬЕ — секретный архив участников легендарной группы. Здесь собраны досье на каждого: привычки, мемы, цитаты, фразы, луки, клички и компромат. Удобный способ вспомнить, кто такой Дима, чем живёт Настя и почему Артём снова в чёрной рубашке. Всё, что ты боялся забыть — мы записали.",
            imageName: "testImage",
            videoName: "persons"
        ),
        CardData(
            title: "Аффирмации",
            description:
                "Получай персональные аффирмации каждый день — чтобы верить в себя, настраиваться на позитив и достигать большего. Просто, искренне и с заботой о твоём настроении.",
            imageName: "testImage",
            videoName: "affirmation"
        ),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .center, spacing: 20) {
                HomeHeader()
                let columns = [
                    GridItem(.adaptive(minimum: 340), spacing: 20)
                ]
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(cards) { card in
                        CardView(
                            title: card.title,
                            description: card.description,
                            imageName: card.imageName,
                            videoName: card.videoName,
                            player: card.videoName.flatMap {
                                videoManager.player(resourceName: $0)
                            }
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .top)
            .padding(.bottom)
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                // Возобновляем все плееры при возвращении в активное состояние
                videoManager.resumeAllPlayers()
            case .inactive, .background:
                // Приостанавливаем все плееры при переходе в неактивное состояние
                videoManager.pauseAllPlayers()
            @unknown default:
                break
            }
        }
        .appBackground()
        .enableInjection()
    }
}

#Preview {
    HomeView()
}
