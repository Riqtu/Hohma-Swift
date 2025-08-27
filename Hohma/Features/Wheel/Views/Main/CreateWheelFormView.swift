import Inject
import SwiftUI

struct CreateWheelFormView: View {
    @ObserveInjection var inject
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = CreateWheelFormViewModel()

    var body: some View {
        NavigationView {

            VStack(spacing: 24) {
                // Заголовок
                VStack(spacing: 8) {
                    Text("Создать колесо")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Выберите название и тему для нового колеса")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)

                // Форма
                VStack(spacing: 20) {
                    // Название колеса
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Название колеса")
                            .font(.headline)
                            .fontWeight(.medium)

                        TextField("Введите название", text: $viewModel.wheelName)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(.thickMaterial)
                            .cornerRadius(12)
                    }
                    .animation(nil, value: UUID())  // Отключаем анимацию только для контента

                    // Выбор темы
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Тема")
                            .font(.headline)
                            .fontWeight(.medium)

                        if viewModel.isLoadingThemes {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Загрузка тем...")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 20)
                        } else if let error = viewModel.error {
                            Text("Ошибка: \(error)")
                                .foregroundColor(.red)
                                .font(.caption)
                        } else {
                            ScrollView {
                                LazyVGrid(
                                    columns: [
                                        GridItem(.flexible()),
                                        GridItem(.flexible()),
                                    ], spacing: 16
                                ) {
                                    ForEach(viewModel.themes) { theme in
                                        ThemeCardView(
                                            theme: theme,
                                            isSelected: viewModel.selectedThemeId == theme.id
                                        ) {
                                            viewModel.selectedThemeId = theme.id
                                        }
                                    }
                                }
                                .padding(.horizontal, 4)
                            }
                        }
                    }

                }
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity)

                Spacer()

                // Кнопки
                VStack(spacing: 12) {
                    Button(action: {
                        Task {
                            await viewModel.createWheel()
                            if viewModel.isSuccess {
                                dismiss()
                            }
                        }
                    }) {
                        HStack {
                            if viewModel.isCreating {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 16, weight: .medium))
                            }

                            Text(viewModel.isCreating ? "Создание..." : "Создать колесо")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .padding(.vertical, 16)
                        .frame(maxWidth: .infinity)
                        .background(
                            viewModel.canCreate ? Color("AccentColor") : Color.gray
                        )
                        .cornerRadius(12)
                    }
                    .disabled(!viewModel.canCreate || viewModel.isCreating)

                    Button("Отмена") {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .appBackground(useVideo: false)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
            }
        }

        .onAppear {
            Task {
                await viewModel.loadThemes()
            }
        }
        .animation(nil, value: UUID())  // Отключаем анимацию только для контента

        .enableInjection()
    }
}

struct ThemeCardView: View {
    let theme: WheelTheme
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                // Превью темы
                AsyncImage(url: URL(string: theme.backgroundImageURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                }
                .frame(height: 100)
                .clipped()
                .cornerRadius(12)

                VStack(spacing: 4) {
                    Text(theme.title)
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    if let description = theme.description {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(
                        color: isSelected
                            ? Color.accentColor.opacity(0.3) : Color.black.opacity(0.1), radius: 4,
                        x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    CreateWheelFormView()
}
