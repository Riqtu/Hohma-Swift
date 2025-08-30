import Inject
import SwiftUI

struct ThemeSelectorView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @ObserveInjection var inject

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "paintbrush")
                    .foregroundColor(.accentColor)
                    .font(.title2)

                Text("Тема приложения")
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()
            }

            VStack(spacing: 8) {
                ForEach(AppTheme.allCases, id: \.self) { theme in
                    ThemeOptionRow(
                        theme: theme,
                        isSelected: viewModel.themeSettings.currentTheme == theme,
                        onSelect: {
                            viewModel.setTheme(theme)
                        }
                    )
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
        .animation(nil, value: UUID())
        .enableInjection()
    }
}

struct ThemeOptionRow: View {
    let theme: AppTheme
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                Image(systemName: theme.iconName)
                    .foregroundColor(isSelected ? .white : .primary)
                    .font(.title3)
                    .frame(width: 24, height: 24)

                Text(theme.displayName)
                    .foregroundColor(isSelected ? .white : .primary)
                    .font(.body)
                    .fontWeight(.medium)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.white)
                        .font(.title3)
                        .fontWeight(.semibold)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(isSelected ? Color("AccentColor") : Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    ThemeSelectorView(viewModel: SettingsViewModel())
        .padding()
}
