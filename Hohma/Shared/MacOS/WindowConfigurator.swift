import SwiftUI

#if os(macOS)
struct WindowConfigurator: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Configurator())
    }

    struct Configurator: NSViewRepresentable {
        func makeNSView(context: Context) -> NSView {
            DispatchQueue.main.async {
                if let window = NSApplication.shared.windows.first {
                    window.titlebarAppearsTransparent = true
                    window.titleVisibility = .hidden
                    window.isMovableByWindowBackground = true
                }
            }
            return NSView()
        }
        func updateNSView(_ nsView: NSView, context: Context) {}
    }
}
#else
// Пустой модификатор для iOS — чтобы не падало и не было ошибок импорта
struct WindowConfigurator: ViewModifier {
    func body(content: Content) -> some View { content }
}
#endif
