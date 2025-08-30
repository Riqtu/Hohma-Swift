//
//  WheelFilterView.swift
//  Hohma
//
//  Created by Assistant on 20.08.2025.
//

import SwiftUI
import Inject

struct WheelFilterView: View {
    @ObserveInjection var inject
    @Binding var selectedFilter: WheelFilter
    let onFilterChanged: (WheelFilter) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(WheelFilter.allCases, id: \.self) { filter in
                    FilterButton(
                        title: filter.displayName,
                        isSelected: selectedFilter == filter
                    ) {
                        selectedFilter = filter
                        onFilterChanged(filter)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

struct FilterButton: View {
    @ObserveInjection var inject
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isSelected ? Color.accentColor : Color.gray.opacity(0.1))
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    WheelFilterView(
        selectedFilter: .constant(.all),
        onFilterChanged: { _ in }
    )
    .padding()
}
