//
//  HorizontalWheelSectionView.swift
//  Hohma
//
//  Created by Artem Vydro on 06.08.2025.
//

import Inject
import SwiftUI

struct HorizontalWheelSectionView: View {
    @ObserveInjection var inject

    let title: String
    let wheels: [WheelWithRelations]
    let isLoading: Bool
    let isLoadingMore: Bool
    let hasMoreData: Bool
    let onWheelTap: (WheelWithRelations) -> Void
    let onWheelDelete: ((String) -> Void)?
    let onLoadMore: (() async -> Void)?

    init(
        title: String,
        wheels: [WheelWithRelations],
        isLoading: Bool = false,
        isLoadingMore: Bool = false,
        hasMoreData: Bool = false,
        onWheelTap: @escaping (WheelWithRelations) -> Void,
        onWheelDelete: ((String) -> Void)? = nil,
        onLoadMore: (() async -> Void)? = nil
    ) {
        self.title = title
        self.wheels = wheels
        self.isLoading = isLoading
        self.isLoadingMore = isLoadingMore
        self.hasMoreData = hasMoreData
        self.onWheelTap = onWheelTap
        self.onWheelDelete = onWheelDelete
        self.onLoadMore = onLoadMore
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Заголовок секции
            HStack {
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding(.horizontal, 20)

            // Горизонтальный скролл с карточками и пагинацией
            if let onLoadMore = onLoadMore {
                // Используем пагинированный скролл
                HorizontalPaginatedScrollView(
                    isLoadingMore: isLoadingMore,
                    hasMoreData: hasMoreData,
                    hasData: !wheels.isEmpty,
                    containerHeight: 180,  // Высота карточек
                    onLoadMore: onLoadMore
                ) {
                    HStack(spacing: 16) {
                        if wheels.isEmpty && !isLoading {
                            HStack {
                                Text("Здесь пока пусто")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                            }
                            .frame(width: UIScreen.main.bounds.width - 40, height: 150)
                            .background(.ultraThinMaterial)
                            .cornerRadius(12)
                        } else {
                            ForEach(wheels) { wheel in
                                WheelCardComponent(
                                    wheel: wheel,
                                    onTap: {
                                        onWheelTap(wheel)
                                    },
                                    onDelete: onWheelDelete != nil
                                        ? {
                                            onWheelDelete?(wheel.id)
                                        } : nil
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                }
            } else {
                // Обычный скролл без пагинации
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 16) {
                        if wheels.isEmpty && !isLoading {
                            HStack {
                                Text("Здесь пока пусто")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                            }
                            .frame(width: UIScreen.main.bounds.width - 40, height: 150)
                            .background(.ultraThinMaterial)
                            .cornerRadius(12)
                        } else {
                            ForEach(wheels) { wheel in
                                WheelCardComponent(
                                    wheel: wheel,
                                    onTap: {
                                        onWheelTap(wheel)
                                    },
                                    onDelete: onWheelDelete != nil
                                        ? {
                                            onWheelDelete?(wheel.id)
                                        } : nil
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                }
            }
        }
        .padding(.bottom, 16)
        .enableInjection()
    }
}
