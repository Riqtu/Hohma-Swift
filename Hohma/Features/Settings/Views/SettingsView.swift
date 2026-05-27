import Inject
import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    let authViewModel: AuthViewModel?
    @ObserveInjection var inject
    @State private var showingWebView = false
    @State private var webViewURL: URL?
    @State private var webViewTitle = ""
    @State private var showingCacheSettings = false
    @State private var showingProfile = false

    private var appVersion: String {
        let short =
            Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        let version = build.map { "\(short) (\($0))" } ?? short
        return String(format: "settings.version".localized, version)
    }

    private var supportEmail: String {
        Bundle.main.object(forInfoDictionaryKey: "SUPPORT_EMAIL") as? String ?? "xxx-zet@mail.ru"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Заголовок
                    VStack(alignment: .leading, spacing: 8) {
                        Text("settings.title".localized)
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text("settings.subtitle".localized)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)

                    // Секция внешнего вида
                    VStack(alignment: .leading, spacing: 16) {
                        Text("settings.appearance".localized)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .padding(.horizontal)

                        ThemeSelectorView(viewModel: viewModel)
                            .padding(.horizontal)
                    }

                    // Дополнительные настройки (можно расширить в будущем)
                    VStack(alignment: .leading, spacing: 16) {
                        Text("settings.general".localized)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .padding(.horizontal)

                        VStack(spacing: 12) {
                            // Кнопка "Мой профиль"
                            if authViewModel != nil {
                                SettingsRow(
                                    icon: "person.circle",
                                    title: "settings.myProfile".localized,
                                    subtitle: "settings.myProfile.subtitle".localized,
                                    action: {
                                        showingProfile = true
                                    }
                                )
                            }

                            // Настройка громкости звука скачек
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "speaker.wave.2")
                                        .foregroundColor(.accentColor)
                                        .font(.title3)
                                        .frame(width: 24, height: 24)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("settings.raceVolume".localized)
                                            .font(.body)
                                            .fontWeight(.medium)
                                            .foregroundColor(.primary)

                                        Text("settings.raceVolume.subtitle".localized)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()
                                }

                                HStack(spacing: 12) {
                                    Image(systemName: "speaker.fill")
                                        .foregroundColor(.secondary)
                                        .font(.caption)

                                    Slider(value: $viewModel.raceSoundVolume, in: 0...1)
                                        .tint(.accentColor)

                                    Image(systemName: "speaker.wave.3.fill")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                }
                                .padding(.leading, 40)

                                Text("\(Int(viewModel.raceSoundVolume * 100))%")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                    .padding(.trailing, 16)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(.ultraThinMaterial)
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)

                            SettingsRow(
                                icon: "externaldrive",
                                title: "settings.cacheManagement".localized,
                                subtitle: "settings.cacheManagement.subtitle".localized,
                                action: {
                                    showingCacheSettings = true
                                }
                            )

                            SettingsRow(
                                icon: "info.circle",
                                title: "settings.about".localized,
                                subtitle: appVersion,
                                action: {
                                    if let url = URL(string: "https://hohma.su/about") {
                                        webViewURL = url
                                        webViewTitle = "settings.about".localized
                                        showingWebView = true
                                    }
                                }
                            )

                            SettingsRow(
                                icon: "questionmark.circle",
                                title: "settings.help".localized,
                                subtitle: "settings.help.subtitle".localized,
                                action: {
                                    if let url = URL(string: "mailto:\(supportEmail)") {
                                        UIApplication.shared.open(url)
                                    }
                                }
                            )
                        }
                        .padding(.horizontal)
                    }

                    // Правовая информация
                    VStack(alignment: .leading, spacing: 16) {
                        Text("settings.legal".localized)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .padding(.horizontal)

                        VStack(spacing: 12) {
                            SettingsRow(
                                icon: "doc.text",
                                title: "settings.privacyPolicy".localized,
                                subtitle: "settings.privacyPolicy.subtitle".localized,
                                action: {
                                    if let url = URL(string: "https://hohma.su/privacy-policy") {
                                        webViewURL = url
                                        webViewTitle = "settings.privacyPolicy".localized
                                        showingWebView = true
                                    }
                                }
                            )

                            SettingsRow(
                                icon: "doc.text.fill",
                                title: "settings.termsOfService".localized,
                                subtitle: "settings.termsOfService.subtitle".localized,
                                action: {
                                    if let url = URL(string: "https://hohma.su/terms-of-service") {
                                        webViewURL = url
                                        webViewTitle = "settings.termsOfService".localized
                                        showingWebView = true
                                    }
                                }
                            )

                            SettingsRow(
                                icon: "person.text.rectangle",
                                title: "settings.userAgreement".localized,
                                subtitle: "settings.userAgreement.subtitle".localized,
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
        .sheet(isPresented: $showingCacheSettings) {
            CacheSettingsView()
        }
        .sheet(isPresented: $showingProfile) {
            if let authViewModel = authViewModel {
                NavigationStack {
                    ProfileView(
                        authViewModel: authViewModel, useNavigationStack: false,
                        showCloseButton: true)
                }
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
    SettingsView(viewModel: SettingsViewModel(), authViewModel: nil)
}
