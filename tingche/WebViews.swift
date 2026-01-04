// Purpose: WebView window and coordinator for parking fee details page.
// Author: Achord <achordchan@gmail.com>
import SwiftUI
import WebKit
import AppKit

// 修改 WebViewWindowController
class WebViewWindowController: NSWindowController, NSWindowDelegate {
    private var coordinator: WebViewCoordinator
    private let account: AccountInfo
    private let dataManager: DataManager
    private var webView: WKWebView
    private var isClosing = false // 添加标志防止重复关闭
    private var onClose: (() -> Void)? // 添加关闭回调

    init(account: AccountInfo, dataManager: DataManager, onClose: (() -> Void)? = nil) {
        self.account = account
        self.dataManager = dataManager
        self.coordinator = WebViewCoordinator()
        self.webView = WKWebView(frame: .zero)
        self.onClose = onClose

        // 创建窗口
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 430 * 0.8, height: 932 * 0.8),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        super.init(window: window)

        // 配置窗口
        window.delegate = self
        window.title = "停车费详情"
        window.center()

        // 配置 WebView
        webView.navigationDelegate = coordinator
        coordinator.webView = webView

        // 设置拦截器
        coordinator.setupInterception(selectedMaxCount: dataManager.settings.selectedMaxCount)

        // 设置 cookies
        let cookies = createCookies(for: account)
        cookies.forEach { cookie in
            webView.configuration.websiteDataStore.httpCookieStore.setCookie(cookie)
        }

        // 创建请求，使用选中的车牌号
        let encodedPlate = dataManager.getEncodedSelectedLicensePlate()
        let parkingURL = "https://m-bms.cmsk1979.com/v/park/parkFee/feeDetails?pid=1256&plate=\(encodedPlate)&barcode=&carInputType=0&mid=11992"
        let url = URL(string: parkingURL)!
        var request = URLRequest(url: url)
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.setValue("https://m-bms.cmsk1979.com/", forHTTPHeaderField: "Origin")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")

        webView.load(request)

        // 创建主视图容器，添加新按钮
        let hostingView = NSHostingView(rootView:
            VStack {
                HStack {
                    // 添加复制链接按钮
                    Button(action: {
                        self.copyURL(parkingURL)
                    }) {
                        Image(systemName: "doc.on.doc")
                            .foregroundColor(.blue)
                            .imageScale(.large)
                            .help("复制链接")
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 4)

                    // 添加在浏览器中打开按钮
                    Button(action: {
                        self.openInBrowser(url)
                    }) {
                        Image(systemName: "safari")
                            .foregroundColor(.green)
                            .imageScale(.large)
                            .help("在浏览器中打开")
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 4)

                    Spacer()

                    // 原有的关闭按钮
                    Button(action: {
                        self.closeWindow()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .imageScale(.large)
                            .help("关闭窗口")
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 4)
                }
                .padding()
                .background(Color(NSColor.windowBackgroundColor))

                WebViewWrapper(webView: webView)
            }
        )

        window.contentView = hostingView
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func closeWindow() {
        // 防止重复关闭
        guard !isClosing else { return }
        isClosing = true

        print("WindowController: 开始关闭窗口...")

        // 先停止加载
        webView.stopLoading()

        // 清理 WebView
        coordinator.cleanupWebView()

        // 关闭窗口
        DispatchQueue.main.async {
            self.window?.close()
            print("WindowController: 窗口已关闭")

            // 调用关闭回调
            self.onClose?()
        }
    }

    // NSWindowDelegate 方法
    func windowWillClose(_ notification: Notification) {
        print("WindowController: 窗口即将关闭")
        closeWindow()
    }

    deinit {
        print("WindowController: 开始释放")
        // 移除 deinit 中的 closeWindow 调用，因为 windowWillClose 会处理
        print("WindowController: 释放完成")
    }

    private func createCookies(for account: AccountInfo) -> [HTTPCookie] {
        let cookieProperties: [[HTTPCookiePropertyKey: Any]] = [
            [.domain: ".cmsk1979.com",
             .path: "/",
             .name: "_token",
             .value: account.token ?? "",
             .secure: true],
            [.domain: ".cmsk1979.com",
             .path: "/",
             .name: "_uid",
             .value: account.uid ?? "",
             .secure: true],
            [.domain: ".cmsk1979.com",
             .path: "/",
             .name: "_uuid",
             .value: "768ccf7d4c29df0ba4ac9267aedf1a83",
             .secure: true],
            [.domain: ".cmsk1979.com",
             .path: "/",
             .name: "_mid",
             .value: "11992",
             .secure: true],
            [.domain: ".cmsk1979.com",
             .path: "/",
             .name: "_mobile",
             .value: account.username,
             .secure: true],
            [.domain: ".cmsk1979.com",
             .path: "/",
             .name: "_userInfo",
             .value: "mobile%3D\(account.username)",
             .secure: true],
            [.domain: ".cmsk1979.com",
             .path: "/",
             .name: "_bussinessSrc",
             .value: "%7B%22BusinessSourceID%22%3A5%7D",
             .secure: true]
        ]

        return cookieProperties.compactMap { HTTPCookie(properties: $0) }
    }

    // 添加复制URL到剪贴板的方法
    private func copyURL(_ urlString: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(urlString, forType: .string)

        // 可选：显示复制成功的反馈
        if let window = self.window {
            let alert = NSAlert()
            alert.messageText = "链接已复制到剪贴板"
            alert.informativeText = urlString
            alert.addButton(withTitle: "确定")
            alert.beginSheetModal(for: window) { _ in }
        }
    }

    // 添加在默认浏览器中打开URL的方法
    private func openInBrowser(_ url: URL) {
        NSWorkspace.shared.open(url)
    }
}

// WebViewCoordinator 添加拦截和修改网络响应的功能
class WebViewCoordinator: NSObject, WKNavigationDelegate, ObservableObject {
    weak var webView: WKWebView?

    // 在 webView 设置后添加拦截脚本
    func setupInterception(selectedMaxCount: Int) {
        guard let webView = webView else { return }

        // 创建拦截 XHR 响应的 JavaScript 脚本
        let script = """
        (function() {
            let originalOpen = XMLHttpRequest.prototype.open;
            let originalSend = XMLHttpRequest.prototype.send;

            XMLHttpRequest.prototype.open = function(method, url) {
                this._url = url;
                return originalOpen.apply(this, arguments);
            };

            XMLHttpRequest.prototype.send = function() {
                let xhr = this;
                let originalOnReadyStateChange = xhr.onreadystatechange;

                xhr.onreadystatechange = function() {
                    if (xhr.readyState === 4) {
                        // 当响应完成时
                        try {
                            let responseText = xhr.responseText;
                            if (responseText && responseText.includes('\"SelectedMaxCount\":')) {
                                // 替换 SelectedMaxCount 值
                                let modifiedResponse = responseText.replace(/\"SelectedMaxCount\":\\d+/g, '\"SelectedMaxCount\":\(selectedMaxCount)');
                                Object.defineProperty(xhr, 'responseText', { value: modifiedResponse });
                                console.log('已修改响应体中的 SelectedMaxCount 为 \(selectedMaxCount)');
                            }
                        } catch (e) {
                            console.error('修改响应失败:', e);
                        }
                    }

                    if (originalOnReadyStateChange) {
                        originalOnReadyStateChange.apply(xhr, arguments);
                    }
                };

                return originalSend.apply(this, arguments);
            };
        })();
        """

        // 创建用户脚本并添加到 WebView 配置中
        let userScript = WKUserScript(
            source: script,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )

        webView.configuration.userContentController.addUserScript(userScript)
        print("已添加响应拦截脚本")
    }

    func cleanupWebView() {
        print("Coordinator: 开始清理 WebView...")

        // 停止所有加载和请求
        webView?.stopLoading()
        print("Coordinator: 已停止加载")

        // 清理所有正在进行的请求
        webView?.configuration.processPool = WKProcessPool()
        print("Coordinator: 已重置进程池")

        // 从父视图中移除
        DispatchQueue.main.async { [weak self] in
            self?.webView?.removeFromSuperview()
            print("Coordinator: 已从父视图移除")
        }

        // 清理 delegate
        webView?.navigationDelegate = nil
        print("Coordinator: 已清理 delegate")

        // 清理 WKWebView
        webView?.configuration.userContentController.removeAllUserScripts()
        webView?.configuration.userContentController.removeAllScriptMessageHandlers()
        print("Coordinator: 已清理 WebView 配置")

        // 清理 cookies 和其他数据
        WKWebsiteDataStore.default().removeData(
            ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
            modifiedSince: Date(timeIntervalSince1970: 0)
        ) {
            print("Coordinator: 已清理所有网站数据")
        }

        // 将 webView 设置为 nil
        webView = nil
        print("Coordinator: WebView 清理完成")
    }

    deinit {
        print("Coordinator: 被释放")
        cleanupWebView()
    }
}

// 新增 WebViewWrapper 结构体
struct WebViewWrapper: NSViewRepresentable {
    let webView: WKWebView

    func makeNSView(context: Context) -> WKWebView {
        webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        // 不需要实现任何更新逻辑
    }
}
