//
//  SidebarButton.swift
//  Hohma
//
//  Created by Artem Vydro on 05.08.2025.
//

import SwiftUI

struct SidebarButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .frame(width: 24)
                Text(title)
                    .fontWeight(isSelected ? .bold : .regular)
                Spacer()
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 8)
            .background(
                isSelected
                ? Color.accentColor.opacity(0.8)
                : Color.clear
            )
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}
