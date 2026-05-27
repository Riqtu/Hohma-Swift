//
//  WheelShapes.swift
//  Hohma
//
//  Created by Artem Vydro on 06.08.2025.
//

import Inject
import SwiftUI

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct WinnerOverlayView: View {
    @ObserveInjection var inject
    let sector: Sector
    let size: CGFloat
    let mainColor: Color

    var body: some View {
        VStack(spacing: 20) {
            Text("Поздравляем!")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)

            if let user: AuthUser = sector.user {
                AvatarView(
                    avatarUrl: user.avatarUrl,
                    userId: user.id,
                    size: 80,
                    fallbackColor: .gray,
                    showBorder: true,
                    borderColor: .white
                )
            } else {
                let initials =
                    sector.name
                    .split(separator: " ")
                    .compactMap { $0.first }
                    .prefix(2)
                let initialsText =
                    initials.isEmpty
                    ? String(sector.name.prefix(2)).uppercased()
                    : String(initials).uppercased()
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.25))
                        .frame(width: 80, height: 80)
                    Text(initialsText)
                        .font(.title2.bold())
                        .foregroundColor(.white)
                }
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                )
            }

            VStack(spacing: 8) {
                Text("\"\(sector.label)\"")
                    .font(.title2)
                    .foregroundColor(.white)

                Text("\(sector.name) - Победитель")
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .frame(width: size, height: size)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [mainColor, Color.gray]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(Circle())
        .transition(.opacity.combined(with: .scale))
        .enableInjection()
    }
}

#Preview {
    return WinnerOverlayView(sector: Sector.mock, size: 235, mainColor: .purple)
}
