import SwiftUI
import WebKit

#if os(iOS)
struct TelegramLoginWebView: UIViewRepresentable {
    var onTokenReceived: (String) -> Void

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        let url = URL(string: "https://oauth.telegram.org/auth?bot_id=7699929262&origin=https%3A%2F%2Friqtu.ru&embed=1&request_access=write&return_to=https%3A%2F%2Friqtu.ru%2F")!
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onTokenReceived: onTokenReceived)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var onTokenReceived: (String) -> Void

        init(onTokenReceived: @escaping (String) -> Void) {
            self.onTokenReceived = onTokenReceived
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let url = navigationAction.request.url {
                print("Навигация по ссылке:", url)
                // Парсим токен из hash
                if let fragment = url.fragment,
                   fragment.starts(with: "tgAuthResult=") {
                    let token = String(fragment.dropFirst("tgAuthResult=".count))
                    print("Перехвачен токен из hash:", token)
                    onTokenReceived(token)
                    decisionHandler(.cancel)
                    return
                }
            }
            decisionHandler(.allow)
        }
    }
}
#elseif os(macOS)
struct TelegramLoginWebView: NSViewRepresentable {
    var onTokenReceived: (String) -> Void

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        let url = URL(string: "https://oauth.telegram.org/auth?bot_id=7699929262&origin=https%3A%2F%2Friqtu.ru&embed=1&request_access=write&return_to=https%3A%2F%2Friqtu.ru%2F")!
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onTokenReceived: onTokenReceived)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var onTokenReceived: (String) -> Void

        init(onTokenReceived: @escaping (String) -> Void) {
            self.onTokenReceived = onTokenReceived
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let url = navigationAction.request.url {
                print("Навигация по ссылке:", url)

                // Парсим токен из hash
                if let fragment = url.fragment,
                   fragment.starts(with: "tgAuthResult=") {
                    let token = String(fragment.dropFirst("tgAuthResult=".count))
                    print("Перехвачен токен из hash:", token)
                    onTokenReceived(token)
                    decisionHandler(.cancel)
                    return
                }
            }
            decisionHandler(.allow)
        }
    }
}
#endif
