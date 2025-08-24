//
//  ScrollViewReader.swift
//  Hohma
//
//  Created by Artem Vydro on 06.08.2025.
//

import SwiftUI
import Inject

struct ScrollViewReader<Content: View>: View {
    @ObserveInjection var inject
    let content: Content
    let onLoadMore: () async -> Void
    let isLoadingMore: Bool
    let hasMoreData: Bool

    @State private var scrollOffset: CGFloat = 0
    @State private var contentHeight: CGFloat = 0
    @State private var scrollViewHeight: CGFloat = 0

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
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    content

                    // Невидимый индикатор для отслеживания конца списка
                    if hasMoreData {
                        Color.clear
                            .frame(height: 200)  // Увеличиваем высоту для более раннего срабатывания
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
                                key: ScrollOffsetPreferenceKey.self,
                                value: contentGeometry.frame(in: .named("scroll")).minY
                            )
                            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                                scrollOffset = value
                                contentHeight = contentGeometry.size.height
                                scrollViewHeight = geometry.size.height

                                // Проверяем, достигли ли мы конца списка
                                let threshold: CGFloat = 200
                                let scrollProgress =
                                    abs(scrollOffset) / (contentHeight - scrollViewHeight)
                                let isNearBottom =
                                    scrollProgress > 0.8
                                    || (abs(scrollOffset) + scrollViewHeight >= contentHeight
                                        - threshold)

                                if isNearBottom && hasMoreData && !isLoadingMore {
                                    Task {
                                        await onLoadMore()
                                    }
                                }
                            }
                    }
                )
            }
            .coordinateSpace(name: "scroll")
        }
    }
}

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Улучшенный ScrollView с пагинацией

struct PaginatedScrollView<Content: View>: View {
    @ObserveInjection var inject
    let content: Content
    let onLoadMore: () async -> Void
    let isLoadingMore: Bool
    let hasMoreData: Bool
    let onRefresh: () async -> Void
    let isRefreshing: Bool
    let hasData: Bool

    init(
        isLoadingMore: Bool,
        hasMoreData: Bool,
        isRefreshing: Bool,
        hasData: Bool,
        onLoadMore: @escaping () async -> Void,
        onRefresh: @escaping () async -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.isLoadingMore = isLoadingMore
        self.hasMoreData = hasMoreData
        self.isRefreshing = isRefreshing
        self.hasData = hasData
        self.onLoadMore = onLoadMore
        self.onRefresh = onRefresh
        self.content = content()
    }

    var body: some View {
        ScrollViewReader(
            isLoadingMore: isLoadingMore,
            hasMoreData: hasMoreData,
            onLoadMore: onLoadMore
        ) {
            VStack(spacing: 20) {
                content

                // Индикатор загрузки дополнительных данных
                if isLoadingMore {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Загрузка...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 10)
                }

                // Индикатор достижения конца списка
                if !hasMoreData && !isLoadingMore && hasData {
                    Text("Все данные загружены")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 10)
                }
            }
        }
        .refreshable {
            await onRefresh()
        }
    }
}
