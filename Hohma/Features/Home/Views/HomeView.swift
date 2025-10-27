import Inject
import SwiftUI

struct HomeView: View {
    @ObserveInjection var inject
    @StateObject private var videoManager = VideoPlayerManager.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .center, spacing: 20) {
                    HomeHeader()
                    let columns = [
                        GridItem(.adaptive(minimum: 340), spacing: 20)
                    ]

                    // Массив карточек (чтобы было удобно генерировать)
                    let cards: [CardData] = [
                        CardData(
                            title: "Скачки",
                            description:
                                "Попробуй свои силы в скачках! Это не просто развлечение — это настоящая гонка, где ты можешь стать победителем. Просто нажми на кнопку, и ты будешь участвовать в скачках с другими игроками. Удачи! - (BETA)",
                            imageName: "testImage",
                            videoName: "races",
                            action: {
                                // Навигация через RootView
                                print("🏠 HomeView: Отправляем уведомление о переходе к скачкам")
                                NotificationCenter.default.post(
                                    name: .navigationRequested,
                                    object: nil,
                                    userInfo: ["destination": "race"]
                                )
                            }
                        ),
                        CardData(
                            title: "Колесо фильмов",
                            description:
                                "Это развлекательный сервис, который помогает выбрать, какой фильм посмотреть. Просто нажми на кнопку, и колесо случайным образом выберет фильм из разных жанров, эпох и стран. Это отличный способ избавиться от мук выбора и открыть для себя новые киноленты!",
                            imageName: "testImage",
                            videoName: "movie",
                            action: {
                                // Навигация через RootView
                                print("🏠 HomeView: Отправляем уведомление о переходе к колесу")
                                NotificationCenter.default.post(
                                    name: .navigationRequested,
                                    object: nil,
                                    userInfo: ["destination": "wheelList"]
                                )
                            }
                        ),

                        // TODO: Add back later
                        // CardData(
                        //     title: "ХОХМА.ДОСЬЕ",
                        //     description:
                        //         "Добро пожаловать в ХОХМА.ДОСЬЕ — секретный архив участников легендарной группы. Здесь собраны досье на каждого: привычки, мемы, цитаты, фразы, луки, клички и компромат. Удобный способ вспомнить, кто такой Дима, чем живёт Настя и почему Артём снова в чёрной рубашке. Всё, что ты боялся забыть — мы записали.",
                        //     imageName: "testImage",
                        //     videoName: "persons",
                        //     action: {
                        //         // Навигация для карточки досье
                        //         // NotificationCenter.default.post(
                        //         //     name: .navigationRequested,
                        //         //     object: nil,
                        //         //     userInfo: ["destination": "dossier"]
                        //         // )
                        //     }
                        // ),
                        // CardData(
                        //     title: "Аффирмации",
                        //     description:
                        //         "Получай персональные аффирмации каждый день — чтобы верить в себя, настраиваться на позитив и достигать большего. Просто, искренне и с заботой о твоём настроении.",
                        //     imageName: "testImage",
                        //     videoName: "affirmation",
                        //     action: {
                        //         // Навигация для карточки аффирмаций
                        //         // NotificationCenter.default.post(
                        //         //     name: .navigationRequested,
                        //         //     object: nil,
                        //         //     userInfo: ["destination": "affirmations"]
                        //         // )
                        //     }
                        // ),
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
                                },
                                action: card.action
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
            .onReceive(NotificationCenter.default.publisher(for: .navigationRequested)) {
                notification in
                if let destination = notification.userInfo?["destination"] as? String {
                    print("🏠 HomeView: Получено уведомление о навигации к \(destination)")
                }
            }
            .appBackground()
            .enableInjection()
        }
    }
}

#Preview {
    HomeView()
}
