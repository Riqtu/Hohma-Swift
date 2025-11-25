import SwiftUI

extension View {
    @ViewBuilder
    func onChangeCompat<Value: Equatable>(
        of value: Value,
        initial: Bool = true,
        _ action: @escaping (_ previous: Value, _ current: Value) -> Void
    ) -> some View {
        if #available(iOS 17.0, *) {
            self.onChange(of: value, initial: initial, action)
        } else {
            self.onChange(of: value) { newValue in
                action(value, newValue)
            }
        }
    }
}

