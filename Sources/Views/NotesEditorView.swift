import SwiftUI
import WebKit

struct NotesEditorView: View {
    @Environment(AppState.self) private var appState
    let agentID: UUID
    let initialContent: String

    var body: some View {
        VditorEditorRepresentable(content: initialContent) { newContent in
            appState.updateAgentNotes(agentID: agentID, content: newContent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - WKWebView Wrapper

struct VditorEditorRepresentable: NSViewRepresentable {
    let content: String
    let onContentChange: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onContentChange: onContentChange)
    }

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.configuration.userContentController.add(context.coordinator, name: "notesChanged")
        webView.configuration.userContentController.add(context.coordinator, name: "editorReady")

        let htmlContent = generateHTML(initialContent: content)
        webView.loadHTMLString(htmlContent, baseURL: nil)

        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    private func generateHTML(initialContent: String) -> String {
        let escapedContent = initialContent
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")

        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/vditor/dist/index.css" />
            <style>
                * { margin: 0; padding: 0; box-sizing: border-box; }
                html, body { height: 100%; width: 100%; }
                #vditor { height: 100%; width: 100%; }
                .vditor { background: #ffffff; }
                .vditor-ir .vditor-reset { 
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                    font-size: 14px;
                    line-height: 1.6;
                }
                .vditor-ir__preview { 
                    background: #f6f8fa; 
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                }
            </style>
        </head>
        <body>
            <div id="vditor"></div>
            <script src="https://cdn.jsdelivr.net/npm/vditor/dist/index.min.js"></script>
            <script>
                let vditor;
                const initialContent = "\(escapedContent)";
                
                const vditorConfig = {
                    mode: 'ir',
                    theme: 'classic',
                    preview: {
                        markdown: {
                            toc: true
                        },
                        theme: {
                            current: 'light',
                            path: 'https://cdn.jsdelivr.net/npm/vditor/dist/css/content-theme/'
                        }
                    },
                    toolbar: [
                        'headings', 'bold', 'italic', 'strike', '|',
                        'list', 'ordered-list', 'check', '|',
                        'quote', 'code', 'inline-code', '|',
                        'link', 'table', '|',
                        'undo', 'redo'
                    ],
                    cache: { enable: false },
                    input: function(value) {
                        window.webkit.messageHandlers.notesChanged.postMessage(value);
                    },
                    after: function() {
                        vditor.setValue(initialContent);
                        window.webkit.messageHandlers.editorReady.postMessage('');
                    }
                };
                
                vditor = new Vditor('vditor', vditorConfig);
            </script>
        </body>
        </html>
        """
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        let onContentChange: (String) -> Void

        init(onContentChange: @escaping (String) -> Void) {
            self.onContentChange = onContentChange
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "notesChanged", let content = message.body as? String {
                onContentChange(content)
            }
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            decisionHandler(.allow)
        }
    }
}
