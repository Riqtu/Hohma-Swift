//
//  SectorsSlideView.swift
//  Hohma
//
//  Created by Artem Vydro on 06.08.2025.
//

import Inject
import SwiftUI

struct SectorsSlideView: View {
    @ObserveInjection var inject
    @Binding var isPresented: Bool
    @Environment(\.dismiss) private var dismiss

    let sectors: [Sector]
    let title: String
    let accentColor: String
    let viewModel: FortuneWheelViewModel?

    var body: some View {

        VStack(spacing: 0) {
            // Заголовок
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(Color("AccentColor"))

                    Text("\(sectors.count) элементов")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 20)

            // Статистика
            HStack(spacing: 24) {
                StatCard(
                    title: "Активные",
                    count: sectors.filter { !$0.eliminated && !$0.winner }.count,
                    color: .green,
                    icon: "circle.fill"
                )

                StatCard(
                    title: "Выбывшие",
                    count: sectors.filter { $0.eliminated }.count,
                    color: .red,
                    icon: "xmark.circle.fill"
                )

                StatCard(
                    title: "Победители",
                    count: sectors.filter { $0.winner }.count,
                    color: Color("AccentColor"),
                    icon: "crown.fill"
                )
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)

            // Список секторов
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(sectors) { sector in
                        SectorSlideRowView(
                            sector: sector,
                            accentColor: accentColor,
                            viewModel: viewModel
                        )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
            .allowsHitTesting(true)  // Разрешаем нажатия
            .contentShape(Rectangle())  // Определяем область для нажатий

        }
        .appBackground(useVideo: false)
        .navigationTitle("Фильмы")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .interactiveDismissDisabled(false)  // Разрешаем свайп для возврата назад
        .onReceive(NotificationCenter.default.publisher(for: .navigationRequested)) {
            notification in
            // Если получаем уведомление о навигации, закрываем экран
            if let destination = notification.userInfo?["destination"] as? String {
                print("🔄 SectorsSlideView: Navigation requested to \(destination), closing view")
                isPresented = false

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
    }

}

struct SectorSlideRowView: View {
    @ObserveInjection var inject
    let sector: Sector
    let accentColor: String
    let viewModel: FortuneWheelViewModel?

    var body: some View {
        HStack(spacing: 12) {
            // Цветной индикатор
            Circle()
                .fill(
                    Color(
                        hue: sector.color.h / 360,
                        saturation: sector.color.s / 100,
                        brightness: sector.color.l / 100
                    )
                )
                .frame(width: 20, height: 20)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
                )

            // Информация о секторе
            VStack(alignment: .leading, spacing: 4) {
                Text(sector.label)
                    .font(.headline)
                    .fontWeight(.semibold)

                Text(sector.name)
                    .font(.subheadline)
                    .foregroundColor(.gray)

                if let user = sector.user {
                    HStack(spacing: 4) {
                        Image(systemName: "person.circle.fill")
                            .font(.caption)
                            .foregroundColor(.gray)

                        Text(user.username ?? "Unknown")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }

            Spacer()

            // Кнопка удаления (только для владельца сектора)
            if let viewModel = viewModel,
                let currentUser = viewModel.user,
                sector.userId == currentUser.id
            {
                Button(action: {
                    viewModel.deleteSector(sector)
                }) {
                    Image(systemName: "trash.circle.fill")
                        .foregroundColor(.red)
                        .font(.title3)
                }
                .buttonStyle(PlainButtonStyle())
            }

            // Статус
            VStack(spacing: 4) {
                if sector.eliminated {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                        .font(.title3)

                    Text("Выбыл")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.red)
                } else if sector.winner {
                    Image(systemName: "crown.fill")
                        .foregroundColor(Color("AccentColor"))
                        .font(.title3)

                    Text("Победитель")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(Color("AccentColor"))
                } else {
                    Image(systemName: "circle.fill")
                        .foregroundColor(.green)
                        .font(.title3)

                    Text("Активен")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color("AccentColor").opacity(0.3), lineWidth: 1)
                )
        )
    }
}

#Preview {
    SectorsSlideView(
        isPresented: .constant(true),
        sectors: [
            Sector.mock,
            Sector.mock,
        ],
        title: "Фильмы",
        accentColor: "#F8D568",
        viewModel: nil
    )
}
