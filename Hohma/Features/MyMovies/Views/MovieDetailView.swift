import SwiftUI

struct MovieDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: MovieDetailViewModel
    let onRemoved: () -> Void

    init(movieId: String, onRemoved: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: MovieDetailViewModel(movieId: movieId))
        self.onRemoved = onRemoved
    }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundPoster

                if viewModel.isLoading && viewModel.movie == nil {
                    ProgressView().tint(.accentColor)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            header
                            actions
                            description
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle(viewModel.movie?.name ?? "Фильм")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .destructiveAction) {
                    Button("Убрать из моих") {
                        viewModel.removeFromMy {
                            dismiss()
                            onRemoved()
                        }
                    }
                    .foregroundColor(.red)
                }
            }
            .onAppear { viewModel.load() }
            .alert("Ошибка", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    private var backgroundPoster: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                Color.black.opacity(0.6)
                if let urlString = viewModel.movie?.backdropUrl
                    ?? viewModel.movie?.posterUrl
                    ?? viewModel.movie?.posterPreviewUrl,
                    let url = URL(string: urlString)
                {
                    CachedAsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: size.width, height: size.height + 200)
                            .clipped()
                            .blur(radius: 18)
                            .overlay(.background.opacity(0.45))
                    } placeholder: {
                        Color.black.opacity(0.6)
                    }
                }
            }
            .ignoresSafeArea()
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            // Постер слева
            if let urlString = viewModel.movie?.posterUrl ?? viewModel.movie?.posterPreviewUrl,
                let url = URL(string: urlString)
            {
                CachedAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    Color.gray.opacity(0.2)
                }
                .frame(width: 120, height: 180)
                .cornerRadius(12)
            }

            // Информация справа
            VStack(alignment: .leading, spacing: 12) {
                if let year = viewModel.movie?.year {
                    Text("Год: \(year)")
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                if let rating = viewModel.movie?.ratingKp {
                    Text(String(format: "Рейтинг KP: %.1f", rating))
                        .font(.headline)
                        .foregroundColor(.accentColor)
                }
                if let genres = viewModel.movie?.genres, !genres.isEmpty {
                    let text = "Жанры: \(genres.map { $0.name }.joined(separator: ", "))"

                    Text(text)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                }
                if let countries = viewModel.movie?.countries, !countries.isEmpty {
                    let text = "Страны: \(countries.map { $0.name }.joined(separator: ", "))"
                    Text(text)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                }

            }

            Spacer()
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(
                isOn: Binding(
                    get: { viewModel.userMovie?.isWatched ?? false },
                    set: { _ in viewModel.toggleWatched() }
                )
            ) {
                Text("Просмотрено")
            }
            .toggleStyle(SwitchToggleStyle(tint: .accentColor))

            if viewModel.userMovie?.isWatched ?? false {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Оценка")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(viewModel.userMovie?.userRating ?? 0)/5")
                            .font(.headline)
                            .foregroundColor(.accentColor)
                    }

                    Slider(
                        value: Binding(
                            get: { Double(viewModel.userMovie?.userRating ?? 0) },
                            set: { viewModel.updateRating(Int($0)) }
                        ),
                        in: 0...5,
                        step: 1
                    )
                    .tint(.accentColor)

                    // Визуальное отображение звезд
                    HStack(spacing: 4) {
                        ForEach(1...5, id: \.self) { index in
                            Image(
                                systemName: index <= (viewModel.userMovie?.userRating ?? 0)
                                    ? "star.fill" : "star"
                            )
                            .foregroundColor(
                                index <= (viewModel.userMovie?.userRating ?? 0)
                                    ? .yellow : .gray.opacity(0.3)
                            )
                            .font(.caption)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }

    private var description: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Описание")
                .font(.headline)
            Text(
                viewModel.movie?.description ?? viewModel.movie?.shortDescription
                    ?? "Описание недоступно"
            )
            .foregroundColor(.secondary)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }
}
