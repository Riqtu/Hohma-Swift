import AVFoundation
import Inject
import SwiftUI

struct WheelCardView: View {
    @ObserveInjection var inject
    @ObservedObject private var viewModel: WheelCardViewModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingGame = false
    @State private var showingDeleteConfirmation = false
    @State private var dragOffset: CGFloat = 0

    let cardData: WheelWithRelations
    let currentUser: AuthUser?
    let onDelete: ((String) -> Void)?

    init(
        cardData: WheelWithRelations, currentUser: AuthUser? = nil,
        onDelete: ((String) -> Void)? = nil
    ) {
        self.cardData = cardData
        self.viewModel = WheelCardViewModel(cardData: cardData)
        self.currentUser = currentUser
        self.onDelete = onDelete
    }

    var body: some View {
        ZStack {
            // Кнопка удаления под карточкой
            HStack {
                Spacer()
                if dragOffset < -30 {
                    Button(action: {
                        showingDeleteConfirmation = true
                        withAnimation(.easeInOut(duration: 0.3)) {
                            dragOffset = 0
                        }
                    }) {
                        Image(systemName: "trash.fill")
                            .foregroundColor(.white)
                            .font(.title2)
                            .frame(width: 60, height: 60)
                            .background(Color.red)
                            .clipShape(Circle())
                    }
                    .padding(.trailing, 20)
                    .scaleEffect(dragOffset < -50 ? 1.0 : 0.8)
                    .opacity(dragOffset < -40 ? 1.0 : 0.6)
                    .rotationEffect(.degrees(dragOffset < -80 ? 0 : -15))
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: dragOffset)
                }
            }

            // Основная карточка
            VStack(alignment: .leading, spacing: 16) {
                // Видео фон с заголовком
                ZStack {
                    if let urlString = cardData.theme?.backgroundVideoURL,
                        let url = URL(string: urlString)
                    {
                        // Используем новый StreamVideoView для внешних URL
                        StreamVideoView(url: url)
                            .frame(minWidth: 330, maxWidth: 380, minHeight: 200)
                            .clipped()
                            .id(urlString)  // Принудительно пересоздаем при изменении URL
                    } else if viewModel.isVideoReady {
                        // Используем старый VideoBackgroundView для локального видео
                        if let player = viewModel.player {
                            VideoBackgroundView(player: player)
                                .frame(minWidth: 330, maxWidth: 380, minHeight: 200)
                        }
                    } else {
                        // Показываем градиент пока видео загружается
                        AnimatedGradientBackground()
                            .frame(minWidth: 330, maxWidth: 380, minHeight: 200)
                    }

                    WheelHeaderView(
                        hasWinner: viewModel.hasWinner,
                        winnerUser: viewModel.winnerUser
                    )
                }

                // Информация о колесе
                VStack(alignment: .leading, spacing: 10) {
                    Text(cardData.name)
                        .font(.system(size: 20))
                        .fontWeight(.bold)
                        .padding(.bottom)

                    if viewModel.hasParticipants {
                        Text("Участники")
                            .font(.body)
                            .fontWeight(.semibold)
                            .padding(.bottom, 10)

                        ParticipantsView(users: viewModel.uniqueUsers)
                    }

                    // Кнопка для запуска игры
                    Button(action: {
                        print("🔄 WheelCardView: Starting game for wheel: \(cardData.name)")
                        showingGame = true
                    }) {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("Играть")
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color("AccentColor"))
                        .cornerRadius(8)
                    }
                    .padding(.top, 10)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .background(.ultraThinMaterial)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.12), radius: 24, x: 0, y: 16)
            .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 1)
            .offset(x: dragOffset)
            .gesture(
                DragGesture(minimumDistance: 30)
                    .onChanged { value in
                        // Обрабатываем только четко горизонтальные жесты
                        let horizontalRatio =
                            abs(value.translation.width) / max(abs(value.translation.height), 1)
                        if horizontalRatio > 2.0 && value.translation.width < 0 {
                            // Ограничиваем максимальный свайп до -120px
                            dragOffset = max(value.translation.width, -120)
                        }
                    }
                    .onEnded { value in
                        let horizontalRatio =
                            abs(value.translation.width) / max(abs(value.translation.height), 1)
                        if horizontalRatio > 2.0 && value.translation.width < -100 {
                            showingDeleteConfirmation = true
                        }
                        withAnimation(.easeInOut(duration: 0.3)) {
                            dragOffset = 0
                        }
                    }
            )
        }
        .onAppear {
            viewModel.onAppear()
        }
        .onDisappear {
            // Не останавливаем видео при исчезновении карточки
            // viewModel.onDisappear()
        }
        .onChange(of: scenePhase) { _, newPhase in
            viewModel.onScenePhaseChanged(newPhase)
        }
        .onChange(of: cardData.id) { _, _ in
            // Обновляем viewModel при изменении cardData
            viewModel.updateCardData(cardData)
        }
        .alert("Удаление колеса", isPresented: $showingDeleteConfirmation) {
            Button("Отмена", role: .cancel) {}
            Button("Удалить", role: .destructive) {
                onDelete?(cardData.id)
            }
        } message: {
            Text(
                "Вы уверены, что хотите удалить колесо \"\(cardData.name)\"? Это действие нельзя отменить."
            )
        }
        .navigationDestination(isPresented: $showingGame) {
            FortuneWheelGameView(wheelData: cardData, currentUser: currentUser)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar(.hidden, for: .tabBar)  // Скрываем TabBar в игре
                .onAppear {
                    print("🔄 WheelCardView: Game view appeared")
                }
                .onDisappear {
                    print("🔄 WheelCardView: Game view disappeared")
                }
                .onReceive(NotificationCenter.default.publisher(for: .navigationRequested)) {
                    notification in
                    // Если получаем уведомление о навигации, закрываем экран игры
                    if let destination = notification.userInfo?["destination"] as? String {
                        print(
                            "🔄 WheelCardView: Navigation requested to \(destination), closing game")
                        showingGame = false

                        // Отправляем дополнительное уведомление для навигации
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            NotificationCenter.default.post(
                                name: .navigationRequested,
                                object: nil,
                                userInfo: ["destination": destination, "force": true]
                            )
                        }
                    }
                }
            // .navigationBarBackButtonHidden(true)
        }
        .enableInjection()
    }
}

#Preview {
    WheelCardView(cardData: .test)
}
