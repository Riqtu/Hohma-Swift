import Inject
import SwiftUI

struct EditWheelFormView: View {
    @ObserveInjection var inject
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: EditWheelFormViewModel

    init(wheel: WheelWithRelations) {
        self._viewModel = StateObject(wrappedValue: EditWheelFormViewModel(wheel: wheel))
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 14) {
                // Удаляем заголовок из VStack
                VStack(spacing: 8) {
                    Text("Измените название, тему и настройки приватности")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 10)

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
                    .animation(nil, value: UUID())

                    // Настройки приватности
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Приватное колесо")
                                    .font(.headline)
                                    .fontWeight(.medium)

                                Text("Приватные колеса не отображаются в общем списке")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Toggle("", isOn: $viewModel.isPrivate)
                                .toggleStyle(SwitchToggleStyle(tint: Color("AccentColor")))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(.thickMaterial)
                        .cornerRadius(12)
                    }

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
                            await viewModel.updateWheel()
                            if viewModel.isSuccess {
                                dismiss()
                            }
                        }
                    }) {
                        HStack {
                            if viewModel.isUpdating {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 16, weight: .medium))
                            }

                            Text(viewModel.isUpdating ? "Сохранение..." : "Сохранить изменения")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .padding(.vertical, 16)
                        .frame(maxWidth: .infinity)
                        .background(
                            viewModel.canUpdate ? Color("AccentColor") : Color.gray
                        )
                        .cornerRadius(12)
                    }
                    .disabled(!viewModel.canUpdate || viewModel.isUpdating)

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
                ToolbarItem(placement: .principal) {
                    Text("Редактировать колесо")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
            }
            .onTapGesture {
                UIApplication.shared.endEditing()
            }
        }
        .onAppear {
            Task {
                await viewModel.loadThemes()
            }
        }
        .animation(nil, value: UUID())
        .enableInjection()
    }
}
