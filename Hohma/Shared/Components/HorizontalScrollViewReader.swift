//
//  HorizontalScrollViewReader.swift
//  Hohma
//
//  Created by Artem Vydro on 06.08.2025.
//

import Inject
import SwiftUI

struct HorizontalScrollViewReader<Content: View>: View {
    @ObserveInjection var inject
    let content: Content
    let onLoadMore: () async -> Void
    let isLoadingMore: Bool
    let hasMoreData: Bool

    @State private var scrollOffset: CGFloat = 0
    @State private var contentWidth: CGFloat = 0
    @State private var scrollViewWidth: CGFloat = 0

    init(
        isLoadingMore: Bool,
        hasMoreData: Bool,
        onLoadMore: @escaping () async -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.isLoadingMore = isLoadingMore
        self.hasMoreData = hasMoreData
        self.onLoadMore = onLoadMore
        self.content = content()
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                content

                // Невидимый индикатор для отслеживания конца списка
                if hasMoreData {
                    Color.clear
                        .frame(width: 200)  // Увеличиваем ширину для более раннего срабатывания
                        .onAppear {
                            if !isLoadingMore {
                                Task {
                                    await onLoadMore()
                                }
                            }
                        }
                }
            }
            .background(
                GeometryReader { contentGeometry in
                    Color.clear
                        .preference(
                            key: HorizontalScrollOffsetPreferenceKey.self,
                            value: contentGeometry.frame(in: .named("horizontalScroll")).minX
                        )
                        .onPreferenceChange(HorizontalScrollOffsetPreferenceKey.self) { value in
                            scrollOffset = value
                            contentWidth = contentGeometry.size.width
                            scrollViewWidth = UIScreen.main.bounds.width

                            // Проверяем, достигли ли мы конца списка
                            let threshold: CGFloat = 200
                            let scrollProgress =
                                abs(scrollOffset) / (contentWidth - scrollViewWidth)
                            let isNearEnd =
                                scrollProgress > 0.8
                                || (abs(scrollOffset) + scrollViewWidth >= contentWidth
                                    - threshold)

                            if isNearEnd && hasMoreData && !isLoadingMore {
                                Task {
                                    await onLoadMore()
                                }
                            }
                        }
                }
            )
        }
        .coordinateSpace(name: "horizontalScroll")
    }
}

struct HorizontalScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Улучшенный горизонтальный ScrollView с пагинацией

struct HorizontalPaginatedScrollView<Content: View>: View {
    @ObserveInjection var inject
    let content: Content
    let onLoadMore: () async -> Void
    let isLoadingMore: Bool
    let hasMoreData: Bool
    let hasData: Bool
    let containerHeight: CGFloat

    init(
        isLoadingMore: Bool,
        hasMoreData: Bool,
        hasData: Bool,
        containerHeight: CGFloat = 200,
        onLoadMore: @escaping () async -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.isLoadingMore = isLoadingMore
        self.hasMoreData = hasMoreData
        self.hasData = hasData
        self.containerHeight = containerHeight
        self.onLoadMore = onLoadMore
        self.content = content()
    }

    var body: some View {
        HorizontalScrollViewReader(
            isLoadingMore: isLoadingMore,
            hasMoreData: hasMoreData,
            onLoadMore: onLoadMore
        ) {
            HStack(spacing: 16) {
                content

                // Индикатор загрузки дополнительных данных
                if isLoadingMore {
                    VStack {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }

                // Индикатор достижения конца списка
                // if !hasMoreData && !isLoadingMore && hasData {
                //     VStack {
                //         Image(systemName: "checkmark.circle.fill")
                //             .foregroundColor(.green)
                //             .font(.title2)
                //         Text("Все загружено")
                //             .font(.caption)
                //             .foregroundColor(.secondary)
                //     }
                //     .frame(width: 100, height: 150)
                //     .background(.ultraThinMaterial)
                //     .cornerRadius(12)
                // }
            }
        }
        .padding(.bottom, 8)
        .frame(height: containerHeight)
    }
}
