import Inject
import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @ObserveInjection var inject
    @State private var showingWebView = false
    @State private var webViewURL: URL?
    @State private var webViewTitle = ""

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
                                subtitle: "Версия 1.3.1",
                                action: {
                                    if let url = URL(string: "https://hohma.su/about") {
                                        webViewURL = url
                                        webViewTitle = "О приложении"
                                        showingWebView = true
                                    }
                                }
                            )

                            SettingsRow(
                                icon: "questionmark.circle",
                                title: "Помощь",
                                subtitle: "Связаться с поддержкой",
                                action: {
                                    if let url = URL(string: "mailto:xxx-zet@mail.ru") {
                                        UIApplication.shared.open(url)
                                    }
                                }
                            )
                        }
                        .padding(.horizontal)
                    }

                    // Правовая информация
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Правовая информация")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .padding(.horizontal)

                        VStack(spacing: 12) {
                            SettingsRow(
                                icon: "doc.text",
                                title: "Политика конфиденциальности",
                                subtitle: "Как мы используем ваши данные",
                                action: {
                                    if let url = URL(string: "https://hohma.su/privacy-policy") {
                                        webViewURL = url
                                        webViewTitle = "Политика конфиденциальности"
                                        showingWebView = true
                                    }
                                }
                            )

                            SettingsRow(
                                icon: "doc.text.fill",
                                title: "Условия использования",
                                subtitle: "Правила использования приложения",
                                action: {
                                    if let url = URL(string: "https://hohma.su/terms-of-service") {
                                        webViewURL = url
                                        webViewTitle = "Условия использования"
                                        showingWebView = true
                                    }
                                }
                            )

                            SettingsRow(
                                icon: "person.text.rectangle",
                                title: "Пользовательское соглашение",
                                subtitle: "Краткие правила",
                                action: {
                                    if let url = URL(string: "https://hohma.su/user-agreement") {
                                        webViewURL = url
                                        webViewTitle = "Пользовательское соглашение"
                                        showingWebView = true
                                    }
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
        .sheet(isPresented: $showingWebView) {
            if let url = webViewURL {
                WebViewSheet(url: url, title: webViewTitle)
            }
        }

        .onChange(of: showingWebView) { _, newValue in
            if !newValue {
                // Сбросить URL при закрытии
                webViewURL = nil
                webViewTitle = ""
            }
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
    SettingsView(viewModel: SettingsViewModel())
}
