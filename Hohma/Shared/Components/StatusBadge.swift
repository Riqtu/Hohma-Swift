//
//  StatusBadge.swift
//  Hohma
//
//  Created by Assistant on 20.08.2025.
//

import Inject
import SwiftUI

struct StatusBadge: View {
    @ObserveInjection var inject
    let status: WheelStatus?

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)

            Text(statusText)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(statusColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.1))
        .cornerRadius(8)
        .enableInjection()
    }

    private var statusColor: Color {
        switch status {
        case .active:
            return .green
        case .inactive:
            return .orange
        case .created:
            return .blue
        case .completed:
            return .purple
        case nil:
            return .gray
        }
    }

    private var statusText: String {
        switch status {
        case .active:
            return "Активно"
        case .inactive:
            return "Неактивно"
        case .created:
            return "Создано"
        case .completed:
            return "Завершено"
        case nil:
            return "Неизвестно"
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        StatusBadge(status: .active)
        StatusBadge(status: .inactive)
        StatusBadge(status: .created)
        StatusBadge(status: .completed)
        StatusBadge(status: nil)
    }
    .padding()
}
