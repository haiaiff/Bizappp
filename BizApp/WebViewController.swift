import UIKit
import WebKit

/// 单页 WKWebView 壳：把内网 ASP.NET 站点包装成原生 iOS App
final class WebViewController: UIViewController {

    // MARK: - 配置

    /// 默认入口地址（App 内可修改并记住）
    private let defaultServer = "http://10.219.62.32:49919/Login.aspx"
    private static let serverKey = "bizapp.serverURL"

    private var serverURL: String {
        get { UserDefaults.standard.string(forKey: WebViewController.serverKey) ?? defaultServer }
        set { UserDefaults.standard.set(newValue, forKey: WebViewController.serverKey) }
    }

    private static let webDarkKey = "bizapp.webDark"

    /// 网页内容跟随深色（对白底老系统注入反色样式）
    private var webDark: Bool {
        get {
            if UserDefaults.standard.object(forKey: WebViewController.webDarkKey) == nil { return true }
            return UserDefaults.standard.bool(forKey: WebViewController.webDarkKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: WebViewController.webDarkKey) }
    }

    // MARK: - 视图

    private var webView: WKWebView!
    private let progressTrack = UIView()
    private let progressFill = UIView()
    private var progressFillWidth: NSLayoutConstraint!
    private let errorState = ErrorStateView()
    private let splash = UIView()
    private var splashStartedAt = Date()
    private var splashRevealed = false

    private var progressObservation: NSKeyValueObservation?
    private var titleObservation: NSKeyValueObservation?
    private var lastDownloadURL: URL?

    // MARK: - 生命周期

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.paper
        setupNavigation()
        setupWebView()
        setupProgressLine()
        setupErrorState()
        setupSplash()
        load()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        traitCollection.userInterfaceStyle == .dark ? .lightContent : .darkContent
    }

    override func traitCollectionDidChange(_ previous: UITraitCollection?) {
        super.traitCollectionDidChange(previous)
        if previous?.userInterfaceStyle != traitCollection.userInterfaceStyle {
            setNeedsStatusBarAppearanceUpdate()
        }
    }

    // MARK: - 导航栏

    private func setupNavigation() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = Theme.paper
        appearance.shadowColor = Theme.line   // 1px 发丝线：网页与外壳同色后，靠这条线交代边界
        appearance.titleTextAttributes = [
            .foregroundColor: Theme.ink,
            .font: Theme.body(15, medium: true)
        ]
        navigationItem.standardAppearance = appearance
        navigationItem.scrollEdgeAppearance = appearance
        navigationItem.compactAppearance = appearance
        navigationItem.title = "业务系统"

        let back = UIBarButtonItem(
            image: UIImage(systemName: "chevron.left",
                           withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)),
            style: .plain, target: self, action: #selector(goBack))
        back.tintColor = Theme.ink
        back.isEnabled = false
        navigationItem.leftBarButtonItem = back

        let more = UIBarButtonItem(
            image: UIImage(systemName: "ellipsis",
                           withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)),
            menu: buildMenu())
        more.tintColor = Theme.ink
        navigationItem.rightBarButtonItem = more
    }

    private func buildMenu() -> UIMenu {
        let reload = UIAction(title: "刷新", image: UIImage(systemName: "arrow.clockwise")) { [weak self] _ in
            self?.reload()
        }
        let home = UIAction(title: "回到登录页", image: UIImage(systemName: "house")) { [weak self] _ in
            self?.load()
        }
        let safari = UIAction(title: "在 Safari 中打开", image: UIImage(systemName: "safari")) { [weak self] _ in
            guard let self = self, let url = URL(string: self.serverURL) else { return }
            UIApplication.shared.open(url)
        }
        let server = UIAction(title: "更换服务器地址", image: UIImage(systemName: "gearshape")) { [weak self] _ in
            self?.presentServerSettings()
        }

        // 网页深色：老系统本身没有 dark 样式，用注入样式把它压到深色
        let webDarkAction = UIAction(
            title: "网页深色",
            image: UIImage(systemName: "circle.lefthalf.filled"),
            state: webDark ? .on : .off
        ) { [weak self] _ in
            guard let self = self else { return }
            self.webDark = !self.webDark
            self.applyWebDark()
            self.navigationItem.rightBarButtonItem?.menu = self.buildMenu()
            self.reload()
        }

        let appearanceActions = Theme.Appearance.allCases.map { value in
            UIAction(title: value.title,
                     state: Theme.appearance == value ? .on : .off) { _ in
                // 等菜单收起再重建根控制器，避免在菜单存续期间换掉它的宿主
                DispatchQueue.main.async { Theme.setAppearance(value) }
            }
        }
        let appearance = UIMenu(title: "外观", image: UIImage(systemName: "moon"), children: appearanceActions)

        return UIMenu(children: [
            reload, home, safari,
            UIMenu(options: .displayInline, children: [webDarkAction, appearance]),
            UIMenu(options: .displayInline, children: [server])
        ])
    }

    // MARK: - 视图构建

    private func setupWebView() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        config.applicationNameForUserAgent = "BizApp/1.0"

        applyWebDark(to: config.userContentController)

        webView = WKWebView(frame: .zero, configuration: config)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.keyboardDismissMode = .interactive
        webView.isOpaque = true
        webView.backgroundColor = Theme.paper
        webView.scrollView.backgroundColor = Theme.paper
        // 安卓式"白底闪一下"在暗色下尤其刺眼，滚动回弹区也用纸色
        webView.underPageBackgroundColor = Theme.paper

        let refresh = UIRefreshControl()
        refresh.tintColor = Theme.ink35
        refresh.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        webView.scrollView.refreshControl = refresh

        view.addSubview(webView)

        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        progressObservation = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] webView, _ in
            self?.updateProgress(CGFloat(webView.estimatedProgress))
        }
        titleObservation = webView.observe(\.title, options: [.new]) { [weak self] webView, _ in
            guard let title = webView.title, !title.isEmpty else { return }
            self?.navigationItem.title = title
        }
    }

    // MARK: - 网页深色

    /// 把反色样式挂到 WebView 配置上；开关变化后需要 reload 才生效
    private func applyWebDark(to controller: WKUserContentController? = nil) {
        let cc = controller ?? webView.configuration.userContentController
        cc.removeAllUserScripts()
        guard webDark else { return }
        cc.addUserScript(WKUserScript(source: WebDark.script,
                                      injectionTime: .atDocumentStart,
                                      forMainFrameOnly: true))
    }

    /// 贴顶的 2pt 细进度线，比系统进度条更克制
    private func setupProgressLine() {
        progressTrack.backgroundColor = Theme.line
        progressTrack.translatesAutoresizingMaskIntoConstraints = false
        progressFill.backgroundColor = Theme.accent
        progressFill.translatesAutoresizingMaskIntoConstraints = false
        progressTrack.addSubview(progressFill)
        view.addSubview(progressTrack)

        progressFillWidth = progressFill.widthAnchor.constraint(equalToConstant: 0)
        NSLayoutConstraint.activate([
            progressTrack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            progressTrack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progressTrack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            progressTrack.heightAnchor.constraint(equalToConstant: 2),

            progressFill.leadingAnchor.constraint(equalTo: progressTrack.leadingAnchor),
            progressFill.topAnchor.constraint(equalTo: progressTrack.topAnchor),
            progressFill.bottomAnchor.constraint(equalTo: progressTrack.bottomAnchor),
            progressFillWidth
        ])
        progressTrack.isHidden = true
    }

    private func updateProgress(_ value: CGFloat) {
        progressTrack.isHidden = value >= 1 || value <= 0
        progressFillWidth.constant = view.bounds.width * min(max(value, 0), 1)
    }

    private func setupErrorState() {
        errorState.translatesAutoresizingMaskIntoConstraints = false
        errorState.isHidden = true
        errorState.onRetry = { [weak self] in self?.reload() }
        errorState.onSettings = { [weak self] in self?.presentServerSettings() }
        view.addSubview(errorState)
        NSLayoutConstraint.activate([
            errorState.topAnchor.constraint(equalTo: view.topAnchor),
            errorState.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            errorState.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            errorState.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupSplash() {
        splash.backgroundColor = Theme.paper
        splash.translatesAutoresizingMaskIntoConstraints = false

        let mark = Theme.label("业务系统", font: Theme.display(21), color: Theme.ink)
        mark.textAlignment = .center
        let rule = UIView()
        rule.backgroundColor = Theme.accent
        rule.translatesAutoresizingMaskIntoConstraints = false
        rule.widthAnchor.constraint(equalToConstant: 28).isActive = true
        rule.heightAnchor.constraint(equalToConstant: 2).isActive = true

        let caption = Theme.label("正在连接内网", font: Theme.micro(10), color: Theme.ink35)
        caption.attributedText = Theme.tracked("CONNECTING", spacing: 1.6)
        caption.textAlignment = .center

        let stack = UIStackView(arrangedSubviews: [mark, rule, caption])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 12
        stack.setCustomSpacing(18, after: rule)
        stack.translatesAutoresizingMaskIntoConstraints = false
        splash.addSubview(stack)
        view.addSubview(splash)

        NSLayoutConstraint.activate([
            splash.topAnchor.constraint(equalTo: view.topAnchor),
            splash.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            splash.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            splash.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.centerXAnchor.constraint(equalTo: splash.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: splash.centerYAnchor)
        ])
        splashStartedAt = Date()
    }

    private func revealSplash() {
        guard !splashRevealed else { return }
        splashRevealed = true
        let elapsed = Date().timeIntervalSince(splashStartedAt)
        let delay = max(0, 0.5 - elapsed)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self else { return }
            UIView.animate(withDuration: 0.4, delay: 0, options: [.curveEaseOut], animations: {
                self.splash.alpha = 0
            }, completion: { _ in
                self.splash.removeFromSuperview()
            })
        }
    }

    // MARK: - 加载

    private func load() {
        guard let url = URL(string: serverURL) else { return }
        webView.load(URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 25))
    }

    private func reload() {
        hideError()
        if webView.url == nil {
            load()
        } else {
            webView.reload()
        }
    }

    @objc private func handleRefresh() {
        reload()
    }

    @objc private func goBack() {
        if webView.canGoBack { webView.goBack() }
    }

    // MARK: - 设置页

    private func presentServerSettings() {
        let vc = ServerSettingsViewController(current: serverURL)
        vc.onSave = { [weak self] url in
            guard let self = self else { return }
            self.serverURL = url
            self.hideError()
            self.load()
        }
        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .pageSheet
        if let sheet = nav.sheetPresentationController {
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 18
        }
        present(nav, animated: true)
    }

    // MARK: - 状态

    private func showError(_ message: String) {
        progressTrack.isHidden = true
        errorState.configure(message: message, server: serverURL)
        revealSplash()
        webView.scrollView.refreshControl?.endRefreshing()
        guard errorState.isHidden else { return }
        errorState.alpha = 0
        errorState.isHidden = false
        UIView.animate(withDuration: 0.28) { self.errorState.alpha = 1 }
    }

    private func hideError() {
        guard !errorState.isHidden else { return }
        UIView.animate(withDuration: 0.2, animations: {
            self.errorState.alpha = 0
        }, completion: { _ in
            self.errorState.isHidden = true
            self.errorState.alpha = 1
        })
    }

    private func updateBackButton() {
        navigationItem.leftBarButtonItem?.isEnabled = webView.canGoBack
    }

    private func toast(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        present(alert, animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            alert.dismiss(animated: true)
        }
    }

    private func message(for error: Error) -> String {
        switch (error as NSError).code {
        case NSURLErrorCannotFindHost:
            return "找不到这个服务器地址。检查一下是否还在公司网络里，或者地址是不是写错了。"
        case NSURLErrorCannotConnectToHost:
            return "服务器没有响应。服务可能没启动，或者端口不通。"
        case NSURLErrorTimedOut:
            return "连接超时。网络较慢，或服务器暂时无响应。"
        case NSURLErrorNotConnectedToInternet:
            return "这台设备现在没有网络，先连上内网 Wi-Fi 再试。"
        default:
            return (error as NSError).localizedDescription
        }
    }
}

// MARK: - WKNavigationDelegate

extension WebViewController: WKNavigationDelegate {

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {

        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }
        let scheme = (url.scheme ?? "").lowercased()
        let host = url.host ?? ""
        let baseHost = URL(string: serverURL)?.host ?? ""

        if scheme == "http" || scheme == "https" {
            if !host.isEmpty && !baseHost.isEmpty && host != baseHost {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
            return
        }

        if ["tel", "mailto", "sms", "itms-apps", "weixin", "alipay", "alipays"].contains(scheme) {
            UIApplication.shared.open(url, options: [:]) { ok in
                if !ok {
                    DispatchQueue.main.async { self.toast("未找到可处理该链接的应用") }
                }
            }
            decisionHandler(.cancel)
            return
        }

        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if !navigationResponse.canShowMIMEType {
            decisionHandler(.download)
            return
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        hideError()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        progressTrack.isHidden = true
        updateBackButton()
        webView.scrollView.refreshControl?.endRefreshing()
        revealSplash()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        updateBackButton()
        if (error as NSError).code == NSURLErrorCancelled { return }
        showError(message(for: error))
    }

    func webView(_ webView: WKWebView,
                 didFailProvisionalNavigation navigation: WKNavigation!,
                 withError error: Error) {
        if (error as NSError).code == NSURLErrorCancelled { return }
        showError(message(for: error))
    }

    // MARK: 下载

    func webView(_ webView: WKWebView,
                 navigationAction: WKNavigationAction,
                 didBecome download: WKDownload) {
        download.delegate = self
    }

    func webView(_ webView: WKWebView,
                 navigationResponse: WKNavigationResponse,
                 didBecome download: WKDownload) {
        download.delegate = self
    }
}

// MARK: - WKUIDelegate

extension WebViewController: WKUIDelegate {

    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        // target=_blank：强制在当前页面打开，避免点了没反应
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
        }
        return nil
    }
}

// MARK: - WKDownloadDelegate

extension WebViewController: WKDownloadDelegate {

    func download(_ download: WKDownload,
                  decideDestinationUsing response: URLResponse,
                  suggestedFilename: String,
                  completionHandler: @escaping (URL?) -> Void) {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let target = dir.appendingPathComponent(suggestedFilename)
        try? FileManager.default.removeItem(at: target)
        lastDownloadURL = target
        completionHandler(target)
    }

    func downloadDidFinish(_ download: WKDownload) {
        guard let url = lastDownloadURL else { return }
        let share = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        present(share, animated: true)
    }

    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        toast("下载失败：\(error.localizedDescription)")
    }
}

// MARK: - 网页反色

/// 老系统没有 dark 样式，这里注入一层“反色 + 色相回正”，把白底页面压到石墨底。
/// 图片按尺寸判断：大图（logo / 照片）反两次保留原色，小图（图标 / 雪碧图）只反一次变成浅色。
private enum WebDark {

    static let script = #"""
    (function () {
      if (window.__bizappDark) { return; }
      window.__bizappDark = true;

      var CSS = [
        ':root{color-scheme:dark}',
        'html{background:#ffffff !important;filter:invert(.94) hue-rotate(180deg);-webkit-font-smoothing:antialiased}',
        'img.__bizapp_keep,video,canvas,object,embed{filter:invert(1) hue-rotate(180deg) !important}'
      ].join('');

      function paint() {
        var s = document.getElementById('__bizapp_dark__');
        if (!s) { s = document.createElement('style'); s.id = '__bizapp_dark__'; }
        s.textContent = CSS;
        (document.head || document.documentElement).appendChild(s);
      }

      function keepColor() {
        var imgs = document.images, i, im;
        for (i = 0; i < imgs.length; i++) {
          im = imgs[i];
          if (im.naturalWidth >= 64 || im.naturalHeight >= 64) {
            im.classList.add('__bizapp_keep');
          } else {
            im.classList.remove('__bizapp_keep');
          }
        }
      }

      paint();
      document.addEventListener('DOMContentLoaded', function () { paint(); keepColor(); });
      window.addEventListener('load', function () { keepColor(); setTimeout(keepColor, 900); });
    })();
    """#
}
