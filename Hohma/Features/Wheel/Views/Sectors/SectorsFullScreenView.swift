//
//  SectorsFullScreenView.swift
//  Hohma
//
//  Created by Artem Vydro on 06.08.2025.
//

import Inject
import SwiftUI

struct SectorsFullScreenView: View {
    @ObserveInjection var inject
    @Environment(\.dismiss) private var dismiss

    let sectors: [Sector]
    let title: String
    let accentColor: String
    let viewModel: FortuneWheelViewModel?

    var body: some View {
        NavigationView {
            ZStack {
                // Фоновый градиент
                LinearGradient(
                    colors: [
                        Color.black,
                        Color(hex: accentColor).opacity(0.1),
                        Color.black,
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Заголовок
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(title)
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(Color(hex: accentColor))

                            Text("\(sectors.count) элементов")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }

                        Spacer()

                        Button(action: {
                            dismiss()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                    // Статистика
                    HStack(spacing: 20) {
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
                            color: Color(hex: accentColor),
                            icon: "crown.fill"
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 20)
                    .shadow(color: Color.black.opacity(0.5), radius: 10, x: 0, y: 10)

                    // Список секторов
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(sectors) { sector in
                                SectorFullScreenRowView(
                                    sector: sector,
                                    accentColor: accentColor,
                                    viewModel: viewModel
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
        }
        .navigationBarHidden(true)
    }
}

struct StatCard: View {
    let title: String
    let count: Int
    let color: Color
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text("\(count)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct SectorFullScreenRowView: View {
    @ObserveInjection var inject
    let sector: Sector
    let accentColor: String
    let viewModel: FortuneWheelViewModel?

    var body: some View {
        HStack(spacing: 16) {
            // Цветной индикатор
            Circle()
                .fill(
                    Color(
                        hue: sector.color.h / 360,
                        saturation: sector.color.s / 100,
                        brightness: sector.color.l / 100
                    )
                )
                .frame(width: 24, height: 24)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 2)
                )

            // Информация о секторе
            VStack(alignment: .leading, spacing: 6) {
                Text(sector.label)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)

                Text(sector.name)
                    .font(.body)
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
                        .font(.title2)
                }
                .buttonStyle(PlainButtonStyle())
            }

            // Статус
            VStack(spacing: 6) {
                if sector.eliminated {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                        .font(.title2)

                    Text("Выбыл")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.red)
                } else if sector.winner {
                    Image(systemName: "crown.fill")
                        .foregroundColor(Color(hex: accentColor))
                        .font(.title2)

                    Text("Победитель")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(Color(hex: accentColor))
                } else {
                    Image(systemName: "circle.fill")
                        .foregroundColor(.green)
                        .font(.title2)

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
                        .stroke(Color(hex: accentColor).opacity(0.3), lineWidth: 1)
                )
        )
    }
}

#Preview {
    SectorsFullScreenView(
        sectors: [
            Sector.mock,
            Sector.mock,
        ],
        title: "Фильмы",
        accentColor: "#F8D568",
        viewModel: nil
    )
}
