import AVFoundation
import Inject
import SwiftUI

enum NavigationDestination: Hashable {
    case wheelList
    case race
    case stats
    case movieBattle
    case profile
}

struct HomeView: View {
    let user: AuthResult?
    let authViewModel: AuthViewModel?
    @ObserveInjection var inject
    @StateObject private var videoManager = VideoPlayerManager.shared
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @State private var navigationPath = NavigationPath()
    @State private var backgroundPlayer: AVPlayer?

    private var isIPhone: Bool {
        UIDevice.current.userInterfaceIdiom == .phone
    }

    private var backgroundVideoName: String {
        colorScheme == .dark ? "back-dark" : "back-light"
    }

    private var overlayColor: Color {
        colorScheme == .dark ? .black : .white
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                // Видеофон на весь экран
                if let player = backgroundPlayer {
                    VideoBackgroundView(player: player)
                        .ignoresSafeArea()
                        .overlay(
                            overlayColor.opacity(0.6)
                                .ignoresSafeArea()
                        )
                } else {
                    // Показываем градиент пока видео загружается
                    AnimatedGradientBackground()
                        .ignoresSafeArea()
                        .overlay(
                            overlayColor.opacity(0.6)
                                .ignoresSafeArea()
                        )
                }

                GeometryReader { geometry in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            HomeHeader(
                                user: user?.user,
                                onStatsTap: {
                                    if isIPhone {
                                        navigationPath.append(NavigationDestination.stats)
                                    } else {
                                        NotificationCenter.default.post(
                                            name: .navigationRequested,
                                            object: nil,
                                            userInfo: ["destination": "stats"]
                                        )
                                    }
                                },
                                onProfileTap: {
                                    AppLogger.shared.debug("Кнопка профиля нажата", category: .ui)
                                    if isIPhone {
                                        AppLogger.shared.debug("iPhone - добавляем profile в navigationPath", category: .ui)
                                        navigationPath.append(NavigationDestination.profile)
                                    } else {
                                        AppLogger.shared.debug("iPad - отправляем уведомление о навигации к profile", category: .ui)
                                        NotificationCenter.default.post(
                                            name: .navigationRequested,
                                            object: nil,
                                            userInfo: ["destination": "profile"]
                                        )
                                    }
                                }
                            )

                            let columns = [
                                GridItem(.adaptive(minimum: 340), spacing: 20)
                            ]

                            // Массив карточек (чтобы было удобно генерировать)
                            let cards: [CardData] = [
                                CardData(
                                    title: "Тайный фильм",
                                    description:
                                        "Новая захватывающая игра! Добавь фильм, нейросеть создаст для него загадочный постер и описание. Участники голосуют за выбывание фильмов, пока не останется один победитель. В конце узнаешь, какие фильмы скрывались за сгенерированными карточками!",
                                    imageName: "testImage",
                                    videoName: "MovieBattle",
                                    action: {
                                        if isIPhone {
                                            // Навигация через NavigationStack для iPhone
                                            AppLogger.shared.debug(
                                                "HomeView: Переход к битве фильмов через NavigationStack", category: .ui)
                                            navigationPath.append(NavigationDestination.movieBattle)
                                        } else {
                                            // Навигация через RootView для iPad
                                            AppLogger.shared.debug(
                                                "HomeView: Отправляем уведомление о переходе к битве фильмов", category: .ui)
                                            NotificationCenter.default.post(
                                                name: .navigationRequested,
                                                object: nil,
                                                userInfo: ["destination": "movieBattle"]
                                            )
                                        }
                                    }
                                ),
                                CardData(
                                    title: "Скачки",
                                    description:
                                        "Попробуй свои силы в скачках! Это не просто развлечение — это настоящая гонка, где ты можешь стать победителем. Просто нажми на кнопку, и ты будешь участвовать в скачках с другими игроками. Удачи! - (BETA)",
                                    imageName: "testImage",
                                    videoName: "races",
                                    action: {
                                        if isIPhone {
                                            // Навигация через NavigationStack для iPhone
                                            AppLogger.shared.debug(
                                                "HomeView: Переход к скачкам через NavigationStack", category: .ui)
                                            navigationPath.append(NavigationDestination.race)
                                        } else {
                                            // Навигация через RootView для iPad
                                            AppLogger.shared.debug(
                                                "HomeView: Отправляем уведомление о переходе к скачкам", category: .ui)
                                            NotificationCenter.default.post(
                                                name: .navigationRequested,
                                                object: nil,
                                                userInfo: ["destination": "race"]
                                            )
                                        }
                                    }
                                ),
                                CardData(
                                    title: "Колесо фильмов",
                                    description:
                                        "Это развлекательный сервис, который помогает выбрать, какой фильм посмотреть. Просто нажми на кнопку, и колесо случайным образом выберет фильм из разных жанров, эпох и стран. Это отличный способ избавиться от мук выбора и открыть для себя новые киноленты!",
                                    imageName: "testImage",
                                    videoName: "movie",
                                    action: {
                                        if isIPhone {
                                            // Навигация через NavigationStack для iPhone
                                            AppLogger.shared.debug(
                                                "HomeView: Переход к колесу через NavigationStack", category: .ui)
                                            navigationPath.append(NavigationDestination.wheelList)
                                        } else {
                                            // Навигация через RootView для iPad
                                            AppLogger.shared.debug(
                                                "HomeView: Отправляем уведомление о переходе к колесу", category: .ui)
                                            NotificationCenter.default.post(
                                                name: .navigationRequested,
                                                object: nil,
                                                userInfo: ["destination": "wheelList"]
                                            )
                                        }
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
                }
            }
            .onAppear {
                setupBackgroundPlayer()
                // Принудительно запускаем видео при возврате на экран
                if let player = backgroundPlayer {
                    if player.currentItem?.status == .readyToPlay {
                        player.play()
                    }
                }
            }
            .onDisappear {
                backgroundPlayer?.pause()
            }
            .onChange(of: colorScheme) { _, _ in
                // Перезагружаем видео при смене темы
                backgroundPlayer?.pause()
                setupBackgroundPlayer()
            }
            .onChange(of: scenePhase) { _, newPhase in
                switch newPhase {
                case .active:
                    // При возврате в приложение явно перезапускаем все видео,
                    // включая фон, чтобы избежать состояния «пауз после бэкграунда»
                    if backgroundPlayer == nil {
                        setupBackgroundPlayer()
                    }
                    if let player = backgroundPlayer {
                        if player.currentItem?.status == .readyToPlay {
                            player.play()
                        } else {
                            // Запускаем, даже если item ещё загружается: плеер сам включится,
                            // когда станет готов (см. VideoPlayerManager)
                            player.play()
                        }
                    }
                    videoManager.resumeAllPlayers()
                case .inactive, .background:
                    videoManager.pauseAllPlayers()
                @unknown default:
                    break
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .navigationRequested)) {
                notification in
                if let destination = notification.userInfo?["destination"] as? String {
                    AppLogger.shared.debug("Получено уведомление о навигации к \(destination)", category: .ui)
                    // Для iPhone обрабатываем навигацию через NavigationPath
                    if isIPhone {
                        if destination == "race" {
                            navigationPath.append(NavigationDestination.race)
                        } else if destination == "wheelList" || destination == "wheel" {
                            navigationPath.append(NavigationDestination.wheelList)
                        } else if destination == "stats" {
                            navigationPath.append(NavigationDestination.stats)
                        } else if destination == "movieBattle" {
                            navigationPath.append(NavigationDestination.movieBattle)
                        } else if destination == "profile" {
                            navigationPath.append(NavigationDestination.profile)
                        }
                    }
                }
            }
            .navigationDestination(for: NavigationDestination.self) { destination in
                switch destination {
                case .wheelList:
                    WheelListView(user: user)
                        .withAppBackground()
                case .race:
                    RaceListView()
                        .withAppBackground()
                case .stats:
                    StatsView()
                        .withAppBackground()
                case .movieBattle:
                    MovieBattleListView()
                        .withAppBackground()
                case .profile:
                    if let authViewModel = authViewModel {
                        ProfileView(authViewModel: authViewModel, useNavigationStack: false)
                            .withAppBackground()
                    } else {
                        // Fallback: создаем новый AuthViewModel если не передан
                        let fallbackAuthViewModel = AuthViewModel()
                        ProfileView(authViewModel: fallbackAuthViewModel, useNavigationStack: false)
                            .withAppBackground()
                    }
                }
            }
            .enableInjection()
        }
    }

    private func setupBackgroundPlayer() {
        let videoName = backgroundVideoName
        // Предварительно загружаем видео
        videoManager.preloadVideo(resourceName: videoName)
        // Получаем плеер (он автоматически запустится когда будет готов)
        backgroundPlayer = videoManager.player(resourceName: videoName)
    }
}

#Preview {
    HomeView(user: nil, authViewModel: nil)
}
