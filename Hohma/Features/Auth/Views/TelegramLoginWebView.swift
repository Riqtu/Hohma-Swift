import SwiftUI
import WebKit

#if os(iOS)
    struct TelegramLoginWebView: UIViewRepresentable {
        var onTokenReceived: (String) -> Void

        func makeUIView(context: Context) -> WKWebView {
            let webView = WKWebView()
            webView.navigationDelegate = context.coordinator

            let botId =
                Bundle.main.object(forInfoDictionaryKey: "TELEGRAM_BOT_ID") as? String
                ?? "7708867557"
            let domain =
                Bundle.main.object(forInfoDictionaryKey: "TELEGRAM_DOMAIN") as? String
                ?? "https://hohma.su"
            let encodedDomain =
                domain.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? domain
            let encodedReturnTo =
                "\(domain)/".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
                ?? "\(domain)/"

            let urlString =
                "https://oauth.telegram.org/auth?bot_id=\(botId)&origin=\(encodedDomain)&embed=1&request_access=write&return_to=\(encodedReturnTo)"
            let url = URL(string: urlString)!
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

            func webView(
                _ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
            ) {
                if let url = navigationAction.request.url {
                    AppLogger.shared.debug("Навигация по ссылке:", category: .auth)
                    // Парсим токен из hash
                    if let fragment = url.fragment,
                        fragment.starts(with: "tgAuthResult=")
                    {
                        let token = String(fragment.dropFirst("tgAuthResult=".count))
                        AppLogger.shared.debug("Перехвачен токен из hash:", category: .auth)
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

            let botId =
                Bundle.main.object(forInfoDictionaryKey: "TELEGRAM_BOT_ID") as? String
                ?? "7708867557"
            let domain =
                Bundle.main.object(forInfoDictionaryKey: "TELEGRAM_DOMAIN") as? String
                ?? "https://hohma.su"
            let encodedDomain =
                domain.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? domain
            let encodedReturnTo =
                "\(domain)/".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
                ?? "\(domain)/"

            let urlString =
                "https://oauth.telegram.org/auth?bot_id=\(botId)&origin=\(encodedDomain)&embed=1&request_access=write&return_to=\(encodedReturnTo)"
            let url = URL(string: urlString)!
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

            func webView(
                _ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
            ) {
                if let url = navigationAction.request.url {
                    AppLogger.shared.debug("Навигация по ссылке:", category: .auth)

                    // Парсим токен из hash
                    if let fragment = url.fragment,
                        fragment.starts(with: "tgAuthResult=")
                    {
                        let token = String(fragment.dropFirst("tgAuthResult=".count))
                        AppLogger.shared.debug("Перехвачен токен из hash:", category: .auth)
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
