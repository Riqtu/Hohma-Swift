import SwiftUI
import Inject

struct ProfileTextField: View {
    @ObserveInjection var inject
    let title: String
    let placeholder: String
    @Binding var text: String
    let icon: String
    
    init(title: String, placeholder: String, text: Binding<String>, icon: String) {
        self.title = title
        self.placeholder = placeholder
        self._text = text
        self.icon = icon
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .fontWeight(.medium)
            
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(.accentColor)
                    .frame(width: 20)
                
                TextField(placeholder, text: $text)
                    .textFieldStyle(PlainTextFieldStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .enableInjection()
    }
}

#Preview {
    VStack(spacing: 20) {
        ProfileTextField(
            title: "Имя пользователя",
            placeholder: "Введите имя пользователя",
            text: .constant(""),
            icon: "person"
        )
        
        ProfileTextField(
            title: "Имя",
            placeholder: "Введите имя",
            text: .constant("Иван"),
            icon: "person.text.rectangle"
        )
    }
    .padding()
}
