import Inject
import SwiftUI

struct PrimaryButton: View {
    @ObserveInjection var inject
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .fontWeight(.semibold)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(Color.accentColor)
                .foregroundColor(.black)
                .cornerRadius(12)
        }
        .enableInjection()
    }
}
