//
//  WheelShapes.swift
//  Hohma
//
//  Created by Artem Vydro on 06.08.2025.
//

import SwiftUI
import Inject

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

    var body: some View {
        VStack(spacing: 20) {
            Text("Поздравляем!")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)

            if let user: AuthUser = sector.user {
                AvatarView(
                    avatarUrl: user.avatarUrl,
                    size: 80,
                    fallbackColor: .gray,
                    showBorder: true,
                    borderColor: .white
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
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black.opacity(0.8))
                .blur(radius: 10)
        )
        .transition(.opacity.combined(with: .scale))
        .enableInjection()
    }
}

#Preview {
    WinnerOverlayView(sector: Sector.mock)
}
