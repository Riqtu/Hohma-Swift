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
    @State private var slideOffset: CGFloat = UIScreen.main.bounds.width
    @State private var backgroundOpacity: Double = 0.0
    @State private var blurRadius: CGFloat = 0.0

    let sectors: [Sector]
    let title: String
    let accentColor: String

    var body: some View {
        ZStack {
            // Размытый и затемненный фон
            ZStack {
                // Размытие фона
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .blur(radius: blurRadius)

                // Дополнительное затемнение
                Color.black.opacity(backgroundOpacity * 0.3)
            }
            .opacity(backgroundOpacity)
            .ignoresSafeArea()
            .onTapGesture {
                dismissView()
            }

            // Основной контент
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    // Безопасная зона сверху
                    Color.clear
                        .frame(height: 0)
                        .safeAreaInset(edge: .top) {
                            Color.clear
                                .frame(height: 0)
                        }

                    // Заголовок
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(title)
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(Color(hex: accentColor))

                            Text("\(sectors.count) элементов")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }

                        Spacer()

                        VStack(spacing: 4) {
                            Button(action: {
                                dismissView()
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.gray)
                            }

                            Text("Свайп вправо")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
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
                            color: Color(hex: accentColor),
                            icon: "crown.fill"
                        )
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)

                    // Список секторов
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(sectors) { sector in
                                SectorSlideRowView(sector: sector, accentColor: accentColor)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 40)
                    }
                }
                .frame(width: UIScreen.main.bounds.width)
                .background(
                    LinearGradient(
                        colors: [
                            Color.black,
                            Color.gray.opacity(0.5),
                            Color.black,
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

                .offset(x: slideOffset)

                .gesture(
                    DragGesture()
                        .onChanged { value in
                            // Отслеживаем свайп вправо для закрытия
                            if value.translation.width > 0 && abs(value.translation.height) < 50 {
                                // Здесь можно добавить логику для анимации при свайпе вправо
                            }
                        }
                        .onEnded { value in
                            // Свайп вправо для закрытия
                            if value.translation.width > 100 && abs(value.translation.height) < 50 {
                                dismissView()
                            }
                        }
                )
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                slideOffset = 0
                backgroundOpacity = 0.7
                blurRadius = 10.0
            }
        }

    }

    private func dismissView() {
        withAnimation(.easeIn(duration: 0.3)) {
            slideOffset = UIScreen.main.bounds.width
            backgroundOpacity = 0.0
            blurRadius = 0.0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isPresented = false
        }
    }

    // Добавляем метод для внешнего управления анимацией
    func animateDismiss() {
        withAnimation(.easeIn(duration: 0.3)) {
            slideOffset = UIScreen.main.bounds.width
        }
    }
}

struct SectorSlideRowView: View {
    @ObserveInjection var inject
    let sector: Sector
    let accentColor: String

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
                    .foregroundColor(.white)

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
                        .foregroundColor(Color(hex: accentColor))
                        .font(.title3)

                    Text("Победитель")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(Color(hex: accentColor))
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
                        .stroke(Color(hex: accentColor).opacity(0.3), lineWidth: 1)
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
        accentColor: "#F8D568"
    )
}
