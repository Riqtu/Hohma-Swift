//
//  HTMLMessageView.swift
//  Hohma
//
//  Created by Artem Vydro on 25.11.2025.
//

import Inject
import SwiftUI
import WebKit

struct HTMLMessageView: UIViewRepresentable {
    @ObserveInjection var inject
    let htmlContent: String
    let isCurrentUser: Bool
    @Binding var contentHeight: CGFloat

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()

        // Настройка для лучшей производительности
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []

        // Создаем WKWebView
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.delegate = context.coordinator

        // Отключаем скролл внутри WebView (высота будет динамической)
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.scrollView.showsHorizontalScrollIndicator = false

        // Прозрачный фон
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear

        // Инжектируем JavaScript для вычисления высоты
        let script = WKUserScript(
            source: """
                function updateHeight() {
                    // Устанавливаем ширину body равной ширине viewport для правильного расчета
                    var body = document.body;
                    var html = document.documentElement;
                    
                    // Получаем ширину viewport
                    var viewportWidth = window.innerWidth || document.documentElement.clientWidth;
                    
                    // Устанавливаем максимальную ширину для body (с учетом padding сообщения ~24px)
                    var maxContentWidth = viewportWidth * 0.75 - 24;
                    body.style.maxWidth = maxContentWidth + 'px';
                    
                    // Вычисляем высоту контента
                    var height = Math.max(
                        body.scrollHeight,
                        body.offsetHeight,
                        html.scrollHeight,
                        html.offsetHeight,
                        html.clientHeight
                    );
                    
                    // Добавляем небольшой отступ для надежности
                    height = Math.ceil(height) + 2;
                    
                    window.webkit.messageHandlers.heightUpdate.postMessage(height);
                }

                // Вызываем при загрузке
                window.addEventListener('load', function() {
                    setTimeout(updateHeight, 50);
                });

                // Вызываем при изменении размера
                var resizeTimeout;
                window.addEventListener('resize', function() {
                    clearTimeout(resizeTimeout);
                    resizeTimeout = setTimeout(updateHeight, 100);
                });

                // Используем MutationObserver для отслеживания изменений контента
                var observer = new MutationObserver(function(mutations) {
                    setTimeout(updateHeight, 50);
                });

                observer.observe(document.body, {
                    childList: true,
                    subtree: true,
                    attributes: true,
                    characterData: true
                });

                // Отслеживаем загрузку изображений
                var images = document.getElementsByTagName('img');
                for (var i = 0; i < images.length; i++) {
                    images[i].addEventListener('load', function() {
                        setTimeout(updateHeight, 50);
                    });
                    images[i].addEventListener('error', function() {
                        setTimeout(updateHeight, 50);
                    });
                }

                // Вызываем сразу после инжекта с несколькими попытками
                setTimeout(updateHeight, 50);
                setTimeout(updateHeight, 200);
                setTimeout(updateHeight, 500);
                """,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )

        configuration.userContentController.addUserScript(script)
        configuration.userContentController.add(context.coordinator, name: "heightUpdate")

        // Загружаем HTML контент
        let htmlString = wrapHTML(htmlContent, isCurrentUser: isCurrentUser)
        webView.loadHTMLString(htmlString, baseURL: nil)

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // Обновляем HTML если контент изменился
        let htmlString = wrapHTML(htmlContent, isCurrentUser: isCurrentUser)
        webView.loadHTMLString(htmlString, baseURL: nil)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // Обертка HTML с базовыми стилями
    private func wrapHTML(_ html: String, isCurrentUser: Bool) -> String {

        return """

                \(html)

            """
    }

    class Coordinator: NSObject, WKNavigationDelegate, UIScrollViewDelegate, WKScriptMessageHandler
    {
        var parent: HTMLMessageView

        init(_ parent: HTMLMessageView) {
            self.parent = parent
        }

        // Обработка обновления высоты из JavaScript
        func userContentController(
            _ userContentController: WKUserContentController, didReceive message: WKScriptMessage
        ) {
            if message.name == "heightUpdate" {
                if let height = message.body as? CGFloat {
                    DispatchQueue.main.async {
                        // Обновляем высоту только если она изменилась значительно
                        let minHeight: CGFloat = 20
                        let newHeight = max(minHeight, height)
                        if abs(self.parent.contentHeight - newHeight) > 2 {
                            self.parent.contentHeight = newHeight
                        }
                    }
                } else if let heightDouble = message.body as? Double {
                    DispatchQueue.main.async {
                        let minHeight: CGFloat = 20
                        let newHeight = max(minHeight, CGFloat(heightDouble))
                        if abs(self.parent.contentHeight - newHeight) > 2 {
                            self.parent.contentHeight = newHeight
                        }
                    }
                }
            }
        }

        // Навигация по ссылкам
        func webView(
            _ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            if navigationAction.navigationType == .linkActivated {
                // Открываем ссылки в Safari
                if let url = navigationAction.request.url {
                    UIApplication.shared.open(url)
                    decisionHandler(.cancel)
                    return
                }
            }
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // После загрузки вызываем обновление высоты несколько раз для надежности
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                webView.evaluateJavaScript("updateHeight();", completionHandler: nil)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                webView.evaluateJavaScript("updateHeight();", completionHandler: nil)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                webView.evaluateJavaScript("updateHeight();", completionHandler: nil)
            }
        }
    }
}

// MARK: - Helper function для определения HTML контента
func isHTMLContent(_ content: String) -> Bool {
    let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)

    // Если строка слишком короткая, не проверяем
    guard trimmed.count > 3 else { return false }

    // Проверяем наличие HTML тегов
    let htmlTagPattern = "<[^>]+>"
    let regex = try? NSRegularExpression(pattern: htmlTagPattern, options: [])
    let range = NSRange(location: 0, length: trimmed.utf16.count)

    if let matches = regex?.matches(in: trimmed, options: [], range: range), !matches.isEmpty {
        // Проверяем, что это действительно HTML, а не просто случайные символы
        let htmlTags = [
            "html", "body", "div", "span", "p", "table", "tr", "td", "th", "thead", "tbody",
            "tfoot", "button", "a", "img", "ul", "ol", "li", "h1", "h2", "h3", "h4", "h5", "h6",
            "br", "strong", "b", "em", "i", "u", "code", "pre", "blockquote", "form", "input",
            "select", "textarea",
        ]

        for match in matches {
            let matchString = (trimmed as NSString).substring(with: match.range)
            let tagName =
                matchString
                .replacingOccurrences(of: "<", with: "")
                .replacingOccurrences(of: ">", with: "")
                .replacingOccurrences(of: "/", with: "")
                .split(separator: " ")
                .first?
                .lowercased() ?? ""

            if htmlTags.contains(tagName) {
                return true
            }
        }
    }

    return false
}
