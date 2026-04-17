// Purpose: WebView window and coordinator for parking fee details page.
// Author: Achord <achordchan@gmail.com>
import SwiftUI
import WebKit
import AppKit

@MainActor
enum ParkingDetailWindowPresenter {
    private static var activeControllers: [UUID: WebViewWindowController] = [:]

    static func present(account: AccountInfo, dataManager: DataManager, onClose: (() -> Void)? = nil) {
        let retainID = UUID()
        let controller = WebViewWindowController(account: account, dataManager: dataManager) {
            activeControllers.removeValue(forKey: retainID)
            onClose?()
        }
        activeControllers[retainID] = controller
        controller.window?.delegate = controller
        controller.showWindow(nil)
    }
}

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
        coordinator.setupInterception(
            selectedMaxCount: dataManager.settings.selectedMaxCount,
            displayPlate: dataManager.settings.selectedLicensePlate,
            mockEnabled: dataManager.settings.mockParkingRightsForParkingView,
            token: account.token
        )

        // 设置 cookies
        let cookies = createCookies(for: account)
        cookies.forEach { cookie in
            webView.configuration.websiteDataStore.httpCookieStore.setCookie(cookie)
        }

        // 创建请求
        let encodedPlate = dataManager.getEncodedLicensePlateForParkingView()
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
class WebViewCoordinator: NSObject, WKNavigationDelegate, ObservableObject, WKScriptMessageHandler {
    weak var webView: WKWebView?

    // 在 webView 设置后添加拦截脚本
    func setupInterception(selectedMaxCount: Int, displayPlate: String, mockEnabled: Bool, token: String?) {
        guard let webView = webView else { return }
        let mockEnabledLiteral = mockEnabled ? "true" : "false"
        let tokenLiteral = token.map { "\"\($0)\"" } ?? "null"

        webView.configuration.userContentController.removeScriptMessageHandler(forName: "tingcheLog")
        webView.configuration.userContentController.add(self, name: "tingcheLog")

        // 创建拦截 XHR 响应的 JavaScript 脚本
        let script = """
        (function() {
            const __tcDisplayPlate = "\(displayPlate)";
            const __tcMockEnabled = \(mockEnabledLiteral);
            const __tcToken = \(tokenLiteral);
            const __tcSelectedMaxCount = \(selectedMaxCount);

            let __tcLastOpenUrl = '';

            function __tcPostLog(level, message, url, extra) {
                try {
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.tingcheLog) {
                        window.webkit.messageHandlers.tingcheLog.postMessage({
                            level: String(level || 'info'),
                            message: String(message || ''),
                            url: String(url || ''),
                            extra: extra || null
                        });
                    }
                } catch (e) {}
            }

            __tcPostLog('info', 'interceptor installed', '', { displayPlate: __tcDisplayPlate, mockEnabled: __tcMockEnabled, hasToken: !!__tcToken });

            const __tcOriginalStringify = JSON.stringify;

            function __tcNormalizeBase64(input) {
                if (typeof input !== 'string') return '';
                let s = input.trim();
                s = s.replace(/\\s+/g, '');
                s = s.replace(/-/g, '+').replace(/_/g, '/');
                const pad = s.length % 4;
                if (pad === 2) s += '==';
                else if (pad === 3) s += '=';
                else if (pad === 1) s = s + '===';
                return s;
            }

            function __tcTryDecodeBase64Json(input) {
                try {
                    const decoded = atob(__tcNormalizeBase64(input));
                    if (!decoded) return null;
                    const t = decoded.trim();
                    if (!(t.startsWith('{') || t.startsWith('['))) return null;
                    return JSON.parse(decoded);
                } catch (e) {
                    return null;
                }
            }

            function __tcLogQueryEnResponse(url, responseText) {
                try {
                    if (!__tcIsQueryEn(url)) return;
                    if (typeof responseText !== 'string' || responseText.length === 0) return;
                    const obj = JSON.parse(responseText);
                    const d = obj && (obj.d || obj.D || obj.data || obj.Data) ? (obj.d || obj.D || obj.data || obj.Data) : null;
                    const list = d && (d.RightsRuleModelList || d.rightsRuleModelList) ? (d.RightsRuleModelList || d.rightsRuleModelList) : null;
                    if (!Array.isArray(list)) return;

                    const summary = [];
                    for (let i = 0; i < list.length; i++) {
                        const item = list[i] || {};
                        const ruleName = item.RuleName || item.ruleName || '';
                        const status = (item.Status != null) ? item.Status : item.status;
                        const tips = item.ListTips || item.listTips || '';
                        const showType = (item.ShowType != null) ? item.ShowType : item.showType;
                        const rights = item.RightsList || item.rightsList;
                        const rightsCount = Array.isArray(rights) ? rights.length : null;
                        if (ruleName || tips || status != null) {
                            summary.push({ ruleName: String(ruleName), status: status, listTips: String(tips), showType: showType, rightsCount: rightsCount });
                        }
                    }
                    __tcPostLog('info', 'QueryEn response summary', url, { traceId: __tcQueryEnTraceId, rules: summary });
                } catch (e) {
                    // ignore
                }
            }

            function __tcMaybeMockQueryEnResponse(url, responseText) {
                try {
                    if (!__tcMockEnabled) return null;
                    if (!__tcIsQueryEn(url)) return null;
                    if (typeof responseText !== 'string' || responseText.length === 0) return null;

                    const obj = JSON.parse(responseText);
                    const d = obj && (obj.d || obj.D || obj.data || obj.Data) ? (obj.d || obj.D || obj.data || obj.Data) : null;
                    const listKey = d && d.RightsRuleModelList ? 'RightsRuleModelList' : (d && d.rightsRuleModelList ? 'rightsRuleModelList' : null);
                    if (!d || !listKey || !Array.isArray(d[listKey])) return null;

                    const rules = d[listKey];
                    let mallRule = null;
                    for (let i = 0; i < rules.length; i++) {
                        const r = rules[i];
                        const ruleName = String((r && (r.RuleName || r.ruleName)) || '');
                        if (ruleName.indexOf('商场停车券') >= 0) {
                            mallRule = r;
                            break;
                        }
                    }
                    if (!mallRule || typeof mallRule !== 'object') return null;

                    const tips = String(mallRule.ListTips || mallRule.listTips || '');
                    const status = (mallRule.Status != null) ? mallRule.Status : mallRule.status;
                    const hasLimit = (tips.indexOf('已达使用上限') >= 0) || (tips.indexOf('每日权益') >= 0) || (status === false);

                    const beforeRights = mallRule.RightsList || mallRule.rightsList;
                    const beforeCount = (beforeRights && beforeRights.length != null) ? beforeRights.length : null;
                    const beforeShowType = (mallRule.ShowType != null) ? mallRule.ShowType : mallRule.showType;

                    let rightsToUse = null;
                    let source = null;
                    try {
                        const cached = localStorage.getItem('tingche_qe_cache_mall_rights_v1');
                        if (cached) {
                            const cachedList = JSON.parse(cached);
                            if (Array.isArray(cachedList) && cachedList.length > 0) {
                                rightsToUse = cachedList;
                                source = 'real_api_or_queryen_cache';
                            }
                        }
                    } catch (e) {}

                    const src2 = localStorage.getItem('tingche_qe_cache_mall_source_v1');

                    // If real_api cache exists, never overwrite it with QueryEn's own list.
                    if (!rightsToUse && !hasLimit) {
                        try {
                            if (src2 !== 'real_api') {
                                const rights = mallRule.RightsList || mallRule.rightsList;
                                if (Array.isArray(rights) && rights.length > 0) {
                                    localStorage.setItem('tingche_qe_cache_mall_rights_v1', __tcOriginalStringify(rights));
                                    localStorage.setItem('tingche_qe_cache_mall_time_v1', String(Date.now()));
                                    localStorage.setItem('tingche_qe_cache_mall_source_v1', 'queryen');
                                    __tcPostLog('info', 'QueryEn cached mall rights list', url, { traceId: __tcQueryEnTraceId, count: rights.length, source: 'queryen' });
                                }
                            }
                        } catch (e) {}
                    }

                    if (!rightsToUse) {
                        __tcPostLog('warn', 'QueryEn mock enabled but no cached mall rights (real api)', url, { traceId: __tcQueryEnTraceId });
                        return null;
                    }

                    // Hard override: create/overwrite the fields unconditionally so UI can't miss it.
                    mallRule.RightsList = rightsToUse;
                    mallRule.rightsList = rightsToUse;
                    mallRule.ShowType = 2;
                    mallRule.showType = 2;
                    mallRule.ListTips = '请选择，' + String(rightsToUse.length) + '张券待使用（Mock）';
                    mallRule.listTips = mallRule.ListTips;
                    mallRule.SelectedMaxCount = __tcSelectedMaxCount;
                    mallRule.selectedMaxCount = __tcSelectedMaxCount;
                    mallRule.PanelTips = '每日可使用' + String(__tcSelectedMaxCount) + '张停车券 -Achord';
                    mallRule.panelTips = mallRule.PanelTips;
                    mallRule.Status = true;
                    mallRule.status = true;
                    mallRule.IsShow = true;
                    mallRule.isShow = true;

                    const t = localStorage.getItem('tingche_qe_cache_mall_time_v1');
                    __tcPostLog('info', 'QueryEn mock applied (mall parking) ', url, { traceId: __tcQueryEnTraceId, hasLimit: hasLimit, source: src2 || source || null, cachedAt: t || null, beforeCount: beforeCount, beforeShowType: beforeShowType, afterCount: (rightsToUse && rightsToUse.length != null) ? rightsToUse.length : null, afterShowType: 2 });
                    return __tcOriginalStringify(obj);
                } catch (e) {
                    return null;
                }
            }

            function __tcBuildRightsItemFromCouponItem(it) {
                try {
                    if (!it || typeof it !== 'object') return null;
                    const name = String(it.Name || '停车券');
                    const vcode = (it.VCode != null) ? String(it.VCode) : '';
                    const ruleNo = (it.RuleNo != null) ? String(it.RuleNo) : '';
                    const enableTime = (it.EnableTime != null) ? String(it.EnableTime) : '';
                    const overdueTime = (it.OverdueTime != null) ? String(it.OverdueTime) : '';
                    const id = vcode || (ruleNo ? (ruleNo + '_' + enableTime + '_' + overdueTime) : String(it.CouponID || ''));
                    let amount = 0;
                    if (it.InsteadMoney != null) {
                        const v = Number(it.InsteadMoney);
                        if (!isNaN(v)) amount = Math.round(v * 100);
                    }
                    if (!amount && name.indexOf('2小时') >= 0) amount = 1000;
                    if (!amount && name.indexOf('1小时') >= 0) amount = 500;
                    if (!amount) amount = 500;
                    return {
                        RuleShowType: 0,
                        OrderRecord: '3',
                        RightsID: id,
                        RightsName: name,
                        RightsType: 0,
                        Amount: amount,
                        AllowanceAmount: 0,
                        Minutes: 0,
                        IsIntellegent: false
                    };
                } catch (e) {
                    return null;
                }
            }

            function __tcPrefetchMallRightsFromRealAPI() {
                try {
                    if (!__tcMockEnabled) return;
                    if (!__tcToken) {
                        __tcPostLog('warn', 'mock enabled but token missing for coupon prefetch', '', {});
                        return;
                    }

                    const body = {
                        MinID: 0,
                        PageSize: 999,
                        MallID: '11992',
                        Header: { Token: __tcToken }
                    };

                    const endpoints = [
                        'https://m-bms.cmsk1979.com/a/coupon/API/mycoupon/GetNotAboutToExpireCoupon',
                        'https://m-bms.cmsk1979.com/a/coupon/API/mycoupon/GetAboutToExpireCoupon'
                    ];

                    function fetchOne(url) {
                        return fetch(url, {
                            method: 'POST',
                            headers: {
                                'Content-Type': 'application/json',
                                'Accept': 'application/json, text/plain, */*',
                                'Origin': 'https://m-bms.cmsk1979.com',
                                'Referer': 'https://m-bms.cmsk1979.com/v/coupon/mycoupon/index?mid=11992'
                            },
                            body: __tcOriginalStringify(body)
                        }).then(function(r) {
                            return r.text().then(function(t) {
                                try {
                                    return JSON.parse(t);
                                } catch (e) {
                                    return null;
                                }
                            });
                        }).catch(function() {
                            return null;
                        });
                    }

                    Promise.all([fetchOne(endpoints[0]), fetchOne(endpoints[1])]).then(function(arr) {
                        try {
                            let all = [];
                            for (let i = 0; i < arr.length; i++) {
                                const o = arr[i];
                                if (o && o.m === 1 && Array.isArray(o.d)) {
                                    all = all.concat(o.d);
                                }
                            }

                            const useStateCounts = {};
                            for (let i = 0; i < all.length; i++) {
                                const it = all[i];
                                const s = (it && it.UseState != null) ? String(it.UseState) : 'null';
                                useStateCounts[s] = (useStateCounts[s] || 0) + 1;
                            }
                            __tcPostLog('info', 'real coupon api fetched', '', { total: all.length, useStateCounts: useStateCounts });

                            const rights = [];
                            const seen = {};
                            for (let i = 0; i < all.length; i++) {
                                const it = all[i];
                                const name = String((it && it.Name) || '');
                                if (name.indexOf('停车券') < 0) continue;
                                const us = (it && it.UseState != null) ? Number(it.UseState) : null;
                                if (us != null && us !== 1 && us !== 3) continue;
                                const r = __tcBuildRightsItemFromCouponItem(it);
                                if (!r || !r.RightsID) continue;
                                if (seen[r.RightsID]) continue;
                                seen[r.RightsID] = true;
                                rights.push(r);
                            }

                            if (rights.length > 0) {
                                localStorage.setItem('tingche_qe_cache_mall_rights_v1', __tcOriginalStringify(rights));
                                localStorage.setItem('tingche_qe_cache_mall_time_v1', String(Date.now()));
                                localStorage.setItem('tingche_qe_cache_mall_source_v1', 'real_api');
                                __tcPostLog('info', 'prefetched mall rights from real coupon api', '', { count: rights.length, total: all.length });
                            } else {
                                __tcPostLog('warn', 'real coupon api returned no usable parking vouchers', '', { total: all.length });
                            }
                        } catch (e) {
                            __tcPostLog('warn', 'prefetch mall rights failed', '', { err: String(e) });
                        }
                    });
                } catch (e) {}
            }

            try {
                setTimeout(function() {
                    try {
                        __tcPrefetchMallRightsFromRealAPI();
                    } catch (e) {}
                }, 600);
            } catch (e) {}

            function __tcIsQueryEn(url) {
                if (!url || typeof url !== 'string') return false;
                // Only target the discount endpoint we are testing.
                if (url.includes('/api/discount/DiscountCore/QueryEn')) return true;
                if (url.includes('DiscountCore/QueryEn')) return true;
                return false;
            }

            let __tcQueryEnTraceId = '';
            let __tcLoggedDataWrapperForTrace = false;

            let originalOpen = XMLHttpRequest.prototype.open;
            let originalSend = XMLHttpRequest.prototype.send;
            let originalSetRequestHeader = XMLHttpRequest.prototype.setRequestHeader;

            XMLHttpRequest.prototype.open = function(method, url) {
                this._url = url;
                __tcLastOpenUrl = url || '';
                this._tcHeaders = {};
                if (__tcIsQueryEn(url || '')) {
                    __tcQueryEnTraceId = String(Date.now()) + '_' + String(Math.random()).slice(2);
                    __tcLoggedDataWrapperForTrace = false;
                }
                return originalOpen.apply(this, arguments);
            };

            XMLHttpRequest.prototype.setRequestHeader = function(name, value) {
                try {
                    if (!this._tcHeaders) this._tcHeaders = {};
                    this._tcHeaders[String(name || '').toLowerCase()] = String(value || '');
                } catch (e) {}
                return originalSetRequestHeader.apply(this, arguments);
            };

            XMLHttpRequest.prototype.send = function() {
                let xhr = this;
                let originalOnReadyStateChange = xhr.onreadystatechange;

                xhr.onreadystatechange = function() {
                    if (xhr.readyState === 4) {
                        // 当响应完成时
                        try {
                            let responseText = xhr.responseText;

                            try {
                                const mocked = __tcMaybeMockQueryEnResponse(xhr._url, responseText);
                                if (mocked && typeof mocked === 'string') {
                                    responseText = mocked;
                                    try {
                                        Object.defineProperty(xhr, 'responseText', {
                                            configurable: true,
                                            get: function() { return responseText; }
                                        });
                                    } catch (e) {}

                                    // Some pages read xhr.response instead of xhr.responseText.
                                    try {
                                        Object.defineProperty(xhr, 'response', {
                                            configurable: true,
                                            get: function() { return responseText; }
                                        });
                                    } catch (e) {}
                                }
                            } catch (e) {}

                            try {
                                __tcLogQueryEnResponse(xhr._url, responseText);
                            } catch (e) {}
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

            const originalFetch = window.fetch;
            if (originalFetch) {
                window.fetch = function(input, init) {
                    return originalFetch.call(this, input, init).then(function(resp) {
                        try {
                            const url = (typeof input === 'string') ? input : (input && input.url ? input.url : '');
                            if (!__tcIsQueryEn(url)) return resp;
                            const cloned = resp.clone();
                            return cloned.text().then(function(txt) {
                                let responseText = txt;

                                try {
                                    const mocked = __tcMaybeMockQueryEnResponse(url, responseText);
                                    if (mocked && typeof mocked === 'string') {
                                        responseText = mocked;
                                    }
                                } catch (e) {}

                                try {
                                    __tcLogQueryEnResponse(url, responseText);
                                } catch (e) {}

                                try {
                                    if (responseText && responseText.includes('"SelectedMaxCount":')) {
                                        responseText = responseText.replace(/"SelectedMaxCount":\\d+/g, '"SelectedMaxCount":\(selectedMaxCount)');
                                    }
                                } catch (e) {}

                                if (responseText !== txt) {
                                    return new Response(responseText, { status: resp.status, statusText: resp.statusText, headers: resp.headers });
                                }
                                return resp;
                            }).catch(function() {
                                return resp;
                            });
                        } catch (e) {
                            return resp;
                        }
                    });
                };
            }
        })();
        """

        // 创建用户脚本并添加到 WebView 配置中
        let userScript = WKUserScript(
            source: script,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )

        webView.configuration.userContentController.removeAllUserScripts()
        webView.configuration.userContentController.addUserScript(userScript)
        print("已添加响应拦截脚本")
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "tingcheLog" else { return }

        let payload = message.body
        let text: String
        if let dict = payload as? [String: Any] {
            let level = dict["level"] as? String ?? "info"
            let msg = dict["message"] as? String ?? ""
            let url = dict["url"] as? String ?? ""
            var extraText = ""
            if let extra = dict["extra"], !(extra is NSNull) {
                if let extraDict = extra as? [String: Any],
                   let data = try? JSONSerialization.data(withJSONObject: extraDict, options: [.sortedKeys]),
                   let s = String(data: data, encoding: .utf8) {
                    extraText = " \(s)"
                } else if let extraArr = extra as? [Any],
                          let data = try? JSONSerialization.data(withJSONObject: extraArr, options: [.sortedKeys]),
                          let s = String(data: data, encoding: .utf8) {
                    extraText = " \(s)"
                } else {
                    extraText = " \(String(describing: extra))"
                }
            }

            text = "[\(level)] \(msg) \(url)\(extraText)"
        } else {
            text = "\(payload)"
        }

        print("[WebView] \(text)")
        Task { @MainActor in
            LogStore.shared.add(category: "WebView", text)
        }
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
