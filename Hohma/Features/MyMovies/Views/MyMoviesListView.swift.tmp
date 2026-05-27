import Inject
import SwiftUI

struct MyMoviesListView: View {
    @ObserveInjection var inject
    @StateObject private var viewModel = MyMoviesListViewModel()
    @State private var selectedMovieId: String?
    @State private var showingAddMovie = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.items.isEmpty {
                    VStack(spacing: 12) {
                        ProgressView("Загрузка...")
                            .tint(.accentColor)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.items.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "film")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("Нет фильмов")
                            .font(.headline)
                        Text("Добавьте фильмы через поиск")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.items) { item in
                                Button {
                                    selectedMovieId = item.movie.id
                                } label: {
                                    MovieRow(item: item)
                                }
                                .contextMenu {
                                    Button(role: .destructive) {
                                        viewModel.remove(item: item)
                                    } label: {
                                        Label("Удалить из моих", systemImage: "trash")
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                            if viewModel.canLoadMore {
                                HStack {
                                    Spacer()
                                    ProgressView()
                                        .onAppear { viewModel.load(reset: false) }
                                    Spacer()
                                }
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal)
                    }
                    .scrollIndicators(.hidden)
                    .refreshable { viewModel.load(reset: true, clearItems: false) }
                    .background(Color.clear)
                }
            }
            .navigationTitle("Мои фильмы")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddMovie = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Добавить фильм")
                }
            }
            .onAppear { viewModel.load(reset: true, clearItems: true) }
            .sheet(isPresented: $showingAddMovie) {
                AddMovieToMyView(
                    onMovieAdded: { movie in
                        viewModel.addMovieOptimistically(from: movie)
                    },
                    onAddError: { movieId in
                        viewModel.rollbackAdd(movieId: movieId)
                    }
                )
                .onDisappear {
                    // Обновляем список после закрытия, чтобы получить актуальные данные с сервера
                    viewModel.refreshAfterAdd()
                }
            }
            .sheet(
                item: Binding(
                    get: {
                        selectedMovieId.map { IdentifiableWrapper(id: $0) }
                    },
                    set: { newValue in
                        let wasOpen = selectedMovieId != nil
                        selectedMovieId = newValue?.id
                        // Если sheet закрылся (был открыт, стал nil), обновляем список
                        if wasOpen && newValue == nil {
                            viewModel.load(reset: true, clearItems: false)
                        }
                    }
                )
            ) { wrapper in
                MovieDetailView(
                    movieId: wrapper.id,
                    onRemoved: {
                        selectedMovieId = nil
                        viewModel.load(reset: true, clearItems: false)
                    }
                )
            }
            .alert("Ошибка", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .withAppBackground()
        }
    }
}

private struct MovieRow: View {
    @ObserveInjection var inject
    let item: MyMovieListItem

    var body: some View {
        HStack(spacing: 12) {
            CachedAsyncImage(
                url: URL(string: item.movie.posterPreviewUrl ?? item.movie.posterUrl ?? "")
            ) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Color.gray.opacity(0.2)
            }
            .frame(width: 60, height: 90)
            .cornerRadius(8)

            VStack(alignment: .leading, spacing: 8) {
                Text(item.movie.name ?? "Без названия")
                    .font(.headline)
                    .lineLimit(2)
                if let year = item.movie.year {
                    HStack(spacing: 8) {
                        Text("\(year)")
                        if let genre = item.movie.genres?.first?.name {
                            Text("· \(genre)")
                        }
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
                if let description = item.movie.description ?? item.movie.shortDescription {
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                if item.isWatched {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Просмотрено")
                            .font(.subheadline)
                        if let r = item.userRating {
                            Text("Оценка: \(r)/5")
                                .font(.subheadline)
                        }
                    }
                }
            }
            Spacer()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .background(.ultraThinMaterial)
        .cornerRadius(12)

    }
}

private struct IdentifiableWrapper: Identifiable {
    let id: String
}
