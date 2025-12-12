//
//  StickerPickerView.swift
//  Hohma
//
//  Created by Assistant on 01.12.2025.
//

import Inject
import SwiftUI

struct StickerPickerView: View {
    @ObserveInjection var inject
    @StateObject private var viewModel = StickerPickerViewModel()
    let onStickerSelected: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Заголовок с паками - компактный
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(viewModel.packs) { pack in
                        PackTabView(
                            pack: pack,
                            isSelected: viewModel.selectedPackId == pack.id,
                            onTap: {
                                viewModel.selectPack(pack.id)
                            }
                        )
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
            }
            .frame(height: 60)  // Фиксированная компактная высота

            Divider()

            // Стикеры выбранного пака
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.stickers.isEmpty {
                VStack {
                    Image(systemName: "face.smiling")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("Стикеры не найдены")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [
                            GridItem(.adaptive(minimum: 80, maximum: 80), spacing: 8)
                        ], spacing: 8
                    ) {
                        ForEach(viewModel.stickers) { sticker in
                            StickerItemView(sticker: sticker) {
                                onStickerSelected(sticker.imageUrl)
                            }
                            .frame(width: 80, height: 80)
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(height: 300)
        .onAppear {
            viewModel.loadPacks()
        }
        .enableInjection()
    }
}

// MARK: - Pack Tab View
private struct PackTabView: View {
    let pack: StickerPack
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                if let iconUrl = pack.iconUrl, let url = URL(string: iconUrl) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Image(systemName: "face.smiling")
                            .foregroundColor(.secondary)
                    }
                    .frame(width: 32, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    Image(systemName: "face.smiling")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                        .frame(width: 32, height: 32)
                        .background(Color(.systemGray5))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }

                Text(pack.name)
                    .font(.system(size: 10))
                    .lineLimit(1)
                    .foregroundColor(isSelected ? .accentColor : .secondary)
            }
            .frame(width: 50)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Sticker Item View
private struct StickerItemView: View {
    let sticker: Sticker
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            if let url = URL(string: sticker.imageUrl) {
                AnimatedStickerView(
                    url: url,
                    isAnimated: sticker.isAnimated,
                    size: CGSize(width: 80, height: 80)
                )
                .frame(width: 80, height: 80)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .clipped()
            } else {
                ProgressView()
                    .frame(width: 80, height: 80)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Sticker Picker ViewModel
@MainActor
private class StickerPickerViewModel: ObservableObject {
    @Published var packs: [StickerPack] = []
    @Published var stickers: [Sticker] = []
    @Published var selectedPackId: String?
    @Published var isLoading: Bool = false

    private let stickerService = StickerService.shared

    func loadPacks() {
        Task {
            isLoading = true
            do {
                let loadedPacks = try await stickerService.getAllPacks(includeInactive: false)
                packs = loadedPacks
                if let firstPack = packs.first {
                    selectPack(firstPack.id)
                }
            } catch {
                AppLogger.shared.error("Failed to load sticker packs: \(error)", category: .ui)
            }
            isLoading = false
        }
    }

    func selectPack(_ packId: String) {
        selectedPackId = packId
        loadStickers(packId: packId)
    }

    private func loadStickers(packId: String) {
        Task {
            isLoading = true
            do {
                let loadedStickers = try await stickerService.getPackStickers(packId: packId)
                stickers = loadedStickers
            } catch {
                AppLogger.shared.error("Failed to load stickers: \(error)", category: .ui)
                stickers = []
            }
            isLoading = false
        }
    }
}

#Preview {
    StickerPickerView { stickerUrl in
        AppLogger.shared.debug("Selected sticker: \(stickerUrl)", category: .ui)
    }
}
