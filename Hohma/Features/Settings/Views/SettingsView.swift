import Inject
import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @ObserveInjection var inject

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Заголовок
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Настройки")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text("Настройте приложение под свои предпочтения")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)

                    // Секция внешнего вида
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Внешний вид")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .padding(.horizontal)

                        ThemeSelectorView(viewModel: viewModel)
                            .padding(.horizontal)
                    }

                    // Дополнительные настройки (можно расширить в будущем)
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Общие")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .padding(.horizontal)

                        VStack(spacing: 12) {
                            SettingsRow(
                                icon: "info.circle",
                                title: "О приложении",
                                subtitle: "Версия 1.0.0",
                                action: {
                                    // Действие для информации о приложении
                                }
                            )

                            SettingsRow(
                                icon: "questionmark.circle",
                                title: "Помощь",
                                subtitle: "FAQ и поддержка",
                                action: {
                                    // Действие для помощи
                                }
                            )
                        }
                        .padding(.horizontal)
                    }

                    Spacer(minLength: 50)
                }
                .padding(.top)
            }
            .appBackground()
            .navigationBarHidden(true)
            .animation(nil, value: UUID())
            .scrollIndicators(.hidden)
        }
        .enableInjection()
    }
}

struct SettingsRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .foregroundColor(.accentColor)
                    .font(.title3)
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    SettingsView()
}
