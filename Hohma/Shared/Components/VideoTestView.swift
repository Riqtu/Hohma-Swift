import AVFoundation
import SwiftUI

struct VideoTestView: View {
    @StateObject private var videoManager = VideoPlayerManager.shared
    @State private var player: AVPlayer?
    @State private var isVideoReady: Bool = false
    @State private var errorMessage: String?
    @State private var useSimpleView: Bool = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Тест видео")
                .font(.title)
                .fontWeight(.bold)

            // Переключатель для тестирования разных компонентов
            Toggle("Использовать простой компонент", isOn: $useSimpleView)
                .padding()

            if let player = player, isVideoReady {
                if useSimpleView {
                    SimpleVideoView(player: player)
                        .frame(width: 300, height: 200)
                        .clipped()
                        .border(Color.green, width: 2)
                } else {
                    VideoBackgroundView(player: player)
                        .frame(width: 300, height: 200)
                        .clipped()
                        .border(Color.blue, width: 2)
                }
            } else {
                Rectangle()
                    .fill(Color.gray)
                    .frame(width: 300, height: 200)
                    .overlay(
                        VStack {
                            if isVideoReady {
                                Text("Видео готово!")
                                    .foregroundColor(.green)
                            } else {
                                ProgressView()
                                    .scaleEffect(1.5)
                                Text("Загрузка видео...")
                                    .foregroundColor(.white)
                            }
                        }
                    )
            }

            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding()
            }

            VStack(spacing: 10) {
                Button("Тест background.mp4") {
                    testVideo(resourceName: "background")
                }
                .buttonStyle(.borderedProminent)

                Button("Тест movie.mp4") {
                    testVideo(resourceName: "movie")
                }
                .buttonStyle(.borderedProminent)

                Button("Тест persons.mp4") {
                    testVideo(resourceName: "persons")
                }
                .buttonStyle(.borderedProminent)

                Button("Тест affirmation.mp4") {
                    testVideo(resourceName: "affirmation")
                }
                .buttonStyle(.borderedProminent)
            }

            if let player = player {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Статус плеера:")
                        .fontWeight(.bold)
                    Text("Готов: \(isVideoReady ? "Да" : "Нет")")
                    Text("Статус: \(player.currentItem?.status.rawValue ?? -1)")
                    Text("Время: \(player.currentTime().seconds)")
                    Text("Длительность: \(player.currentItem?.duration.seconds ?? 0)")
                    Text("Воспроизводится: \(player.timeControlStatus == .playing ? "Да" : "Нет")")
                }
                .font(.caption)
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
            }
        }
        .padding()
        .onAppear {
            // Автоматически тестируем background.mp4 при загрузке
            testVideo(resourceName: "background")
        }
    }

    private func testVideo(resourceName: String) {
        print("🧪 VideoTestView: Тестируем \(resourceName)")

        // Получаем плеер
        if let newPlayer = videoManager.player(resourceName: resourceName) {
            self.player = newPlayer
            setupPlayerObserver(newPlayer)
        } else {
            errorMessage = "Не удалось создать плеер для \(resourceName)"
        }
    }

    private func setupPlayerObserver(_ player: AVPlayer) {
        let observer = player.currentItem?.observe(\.status, options: [.new]) { item, _ in
            DispatchQueue.main.async {
                print("🧪 VideoTestView: Статус плеера: \(item.status.rawValue)")
                self.isVideoReady = item.status == .readyToPlay

                if item.status == .failed {
                    self.errorMessage =
                        "Ошибка загрузки: \(item.error?.localizedDescription ?? "неизвестная ошибка")"
                } else if item.status == .readyToPlay {
                    self.errorMessage = nil
                    // Принудительно запускаем воспроизведение
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        print("🧪 VideoTestView: Принудительно запускаем воспроизведение")
                        player.play()
                    }
                }
            }
        }

        // Проверяем текущий статус
        if player.currentItem?.status == .readyToPlay {
            print("🧪 VideoTestView: Плеер уже готов")
            self.isVideoReady = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                print("🧪 VideoTestView: Принудительно запускаем воспроизведение (уже готов)")
                player.play()
            }
        }
    }
}

#Preview {
    VideoTestView()
}
