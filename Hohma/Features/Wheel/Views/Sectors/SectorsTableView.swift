//
//  SectorsTableView.swift
//  Hohma
//
//  Created by Artem Vydro on 06.08.2025.
//

import SwiftUI
import Inject

struct SectorsTableView: View {
    @ObserveInjection var inject
    let sectors: [Sector]
    let title: String
    let accentColor: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(Color(hex: accentColor))

            if sectors.isEmpty {
                Text("Нет элементов")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(sectors) { sector in
                        SectorRowView(sector: sector, accentColor: accentColor)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(hex: accentColor).opacity(0.3), lineWidth: 1)
                )
        )
        .frame(maxWidth: 200)
    }
}

struct SectorRowView: View {
    @ObserveInjection var inject
    let sector: Sector
    let accentColor: String

    var body: some View {
        HStack(spacing: 8) {
            // Цветной индикатор
            Circle()
                .fill(
                    Color(
                        hue: sector.color.h / 360, saturation: sector.color.s / 100,
                        brightness: sector.color.l / 100)
                )
                .frame(width: 12, height: 12)

            // Информация о секторе
            VStack(alignment: .leading, spacing: 2) {
                Text(sector.label)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(sector.name)
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }

            Spacer()

            // Статус
            if sector.eliminated {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
                    .font(.caption)
            } else if sector.winner {
                Image(systemName: "crown.fill")
                    .foregroundColor(Color(hex: accentColor))
                    .font(.caption)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.05))
        )
    }
}

#Preview {
    SectorsTableView(
        sectors: [
            Sector.mock,
            Sector.mock,
        ],
        title: "Фильмы",
        accentColor: "#F8D568"
    )
    .background(Color.black)
}
