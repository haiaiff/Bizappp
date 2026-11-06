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
    private static let centerPageKey = "bizapp.centerPage"

    /// 网页内容跟随深色（对白底老系统注入反色样式）
    private var webDark: Bool {
        get {
            if UserDefaults.standard.object(forKey: WebViewController.webDarkKey) == nil { return true }
            return UserDefaults.standard.bool(forKey: WebViewController.webDarkKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: WebViewController.webDarkKey) }
    }

    /// 内容明显短于屏幕时垂直居中（登录页这类"上面一小块、下面一大片空"的页面）
    private var centerPage: Bool {
        get {
            if UserDefaults.standard.object(forKey: WebViewController.centerPageKey) == nil { return true }
            return UserDefaults.standard.bool(forKey: WebViewController.centerPageKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: WebViewController.centerPageKey) }
    }

    /// 布局宽度：0 = 跟随设备；其他值 = 按该宽度排版（老系统固定像素布局的应急开关）
    private static let layoutWidthKey = "bizapp.layoutWidth"

    private static let autoFitKey = "bizapp.autoFit"

    /// 窄内容自动铺满（带溢出自检）。默认开，出问题可以一键关掉
    private var autoFit: Bool {
        get {
            if UserDefaults.standard.object(forKey: WebViewController.autoFitKey) == nil { return true }
            return UserDefaults.standard.bool(forKey: WebViewController.autoFitKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: WebViewController.autoFitKey)
            WebInjection.autoFit = newValue
        }
    }

    private var layoutWidth: Int {
        get {
            // v2.0 起默认 device-width：让页面按屏幕宽度重排，而不是按 980 排版再整体缩小
            if UserDefaults.standard.object(forKey: WebViewController.layoutWidthKey) == nil { return 0 }
            return UserDefaults.standard.integer(forKey: WebViewController.layoutWidthKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: WebViewController.layoutWidthKey) }
    }

    /// 网页缩放（1.0 = 100%）。老系统不改布局放不大小字，交给用户按页面自己调
    private static let pageZoomKey = "bizapp.pageZoom"

    private var pageZoom: CGFloat {
        get {
            let v = UserDefaults.standard.double(forKey: WebViewController.pageZoomKey)
            return v > 0 ? CGFloat(v) : 1.0
        }
        set {
            UserDefaults.standard.set(Double(newValue), forKey: WebViewController.pageZoomKey)
            webView?.pageZoom = newValue
        }
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
        navigationItem.title = "MES系统"

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
            self.applyInjection()
            self.navigationItem.rightBarButtonItem?.menu = self.buildMenu()
            self.reload()
        }

        // 登录页适配：老系统按桌面排版，手机上内容被压到 0.38 倍，放大到占宽约 77% 并上移
        let centerAction = UIAction(
            title: "登录页适配",
            image: UIImage(systemName: "rectangle.center.inset.filled"),
            state: centerPage ? .on : .off
        ) { [weak self] _ in
            guard let self = self else { return }
            self.centerPage = !self.centerPage
            self.applyInjection()
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

        // 自动缩放会把固定像素的老布局撑坏，改成手动：按当前页面试，满意就留着
        let zoomLevels: [CGFloat] = [0.9, 1.0, 1.1, 1.25, 1.4]
        let zoomActions = zoomLevels.map { level in
            UIAction(title: "\(Int(level * 100))%",
                     state: abs(pageZoom - level) < 0.01 ? .on : .off) { [weak self] _ in
                guard let self = self else { return }
                self.pageZoom = level
                self.navigationItem.rightBarButtonItem?.menu = self.buildMenu()
            }
        }
        let zoom = UIMenu(title: "页面缩放", image: UIImage(systemName: "textformat.size"), children: zoomActions)

        let widths: [(Int, String)] = [(0, "自适应"), (768, "768"), (980, "980"), (1200, "1200")]
        let widthActions = widths.map { pair -> UIAction in
            let (w, title) = pair
            return UIAction(title: title, state: layoutWidth == w ? .on : .off) { [weak self] _ in
                guard let self = self else { return }
                self.layoutWidth = w
                self.applyInjection()
                self.navigationItem.rightBarButtonItem?.menu = self.buildMenu()
                self.reload()
            }
        }
        let layout = UIMenu(title: "布局宽度", image: UIImage(systemName: "arrow.left.and.right"), children: widthActions)

        let fitAction = UIAction(
            title: "手机排版",
            image: UIImage(systemName: "arrow.up.left.and.arrow.down.right"),
            state: autoFit ? .on : .off
        ) { [weak self] _ in
            guard let self = self else { return }
            self.autoFit = !self.autoFit
            self.applyInjection()
            self.navigationItem.rightBarButtonItem?.menu = self.buildMenu()
            self.reload()
        }

        let export = UIAction(title: "导出页面结构", image: UIImage(systemName: "square.and.arrow.up")) { [weak self] _ in
            self?.exportStructure()
        }
        let diag = UIAction(title: "页面诊断", image: UIImage(systemName: "stethoscope")) { [weak self] _ in
            self?.showDiagnostics()
        }
        let resetZoom = UIAction(title: "缩放重置为 100%", image: UIImage(systemName: "arrow.counterclockwise")) { [weak self] _ in
            guard let self = self else { return }
            self.pageZoom = 1.0
            self.navigationItem.rightBarButtonItem?.menu = self.buildMenu()
        }

        return UIMenu(children: [
            reload, home, safari,
            UIMenu(options: .displayInline, children: [webDarkAction, centerAction, appearance, fitAction, zoom, layout]),
            UIMenu(options: .displayInline, children: [resetZoom, diag, export]),
            UIMenu(options: .displayInline, children: [server])
        ])
    }

    /// 页面诊断：把视口、缩放、实际排版的真实数值读出来，避免再靠猜
    private func showDiagnostics() {
        let js = """
        (function(){
          var d=document, w=window, b=d.body;
          var vp=d.querySelector('meta[name=viewport]');
          var big=null, area=0;
          if(b){ var ns=b.getElementsByTagName('*');
            for(var i=0;i<Math.min(ns.length,800);i++){
              var r=ns[i].getBoundingClientRect();
              if(r.width<80||r.height<40){continue;}
              var a=r.width*r.height; if(a>area){area=a;big=ns[i];}
            } }
          return JSON.stringify({
            vw:w.innerWidth, vh:w.innerHeight, dpr:w.devicePixelRatio,
            visualScale:(w.visualViewport||{}).scale,
            cssZoom:d.documentElement.style.zoom||'(none)',
            viewport:vp?vp.content:'(none)',
            bodyW:b?b.scrollWidth:-1,
            docW:d.documentElement.scrollWidth,
            baseFont:b?getComputedStyle(b).fontSize:'',
            injected:!!window.__bizappInjected,
            reflow:(window.__bz_reflow||null),
            iframes:d.querySelectorAll('iframe').length,
            bigBox: big?(big.tagName+' '+Math.round(big.getBoundingClientRect().width)+'px'):'-',
            widest: (function(){
              var ns=d.getElementsByTagName('*'), out=[], i, r;
              for(i=0;i<ns.length;i++){
                r=ns[i].getBoundingClientRect();
                if(r.width > w.innerWidth*1.15){
                  out.push(ns[i].tagName+(ns[i].className?('.'+String(ns[i].className).split(' ')[0]):'')+'='+Math.round(r.width));
                }
                if(out.length>60){break;}
              }
              return out.slice(0,6).join(', ');
            })()
          });
        })()
        """
        webView.evaluateJavaScript(js) { [weak self] result, error in
            guard let self = self else { return }
            var body = (result as? String) ?? "读取失败"
            if let err = error { body = "读取失败：" + err.localizedDescription }
            let text = "pageZoom=" + String(format: "%.2f", self.pageZoom) + "\n" + body
            let alert = UIAlertController(title: "页面诊断", message: text, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "拷贝", style: .default) { _ in
                UIPasteboard.general.string = text
            })
            alert.addAction(UIAlertAction(title: "好", style: .cancel))
            self.present(alert, animated: true)
        }
    }

    /// 导出当前页面的结构摘要：谁最宽、谁被裁、容器是什么样。
    /// 只发结构不发数据，用来在不看真实 DOM 的情况下定位布局问题。
    private func exportStructure() {
        let js = #"""
        (function(){
          var d = document, w = window, b = d.body;
          if (!b) { return "no body"; }
          function tag(el) {
            var t = el.tagName.toLowerCase();
            if (el.id) { t += "#" + el.id; }
            var c = String(el.className || "").split(/\s+/).filter(Boolean).slice(0, 2);
            if (c.length) { t += "." + c.join("."); }
            return t;
          }
          function txt(el) {
            return String(el.textContent || "").replace(/\s+/g, " ").trim().slice(0, 28);
          }
          var nodes = b.getElementsByTagName("*");
          var n = Math.min(nodes.length, 2000);
          var wide = [], clipped = [], boxes = [];
          for (var i = 0; i < n; i++) {
            var el = nodes[i], r = el.getBoundingClientRect();
            if (r.width <= 0 || r.height <= 0) { continue; }
            var cs = w.getComputedStyle(el);
            if (r.width > w.innerWidth * 1.02 && wide.length < 6) {
              wide.push(tag(el) + " w=" + Math.round(r.width) + " " + txt(el));
            }
            var cw = el.clientWidth, sw = el.scrollWidth;
            var hid = (cs.overflowX === "hidden" || cs.overflow === "hidden" || cs.whiteSpace === "nowrap");
            if (hid && cw > 30 && sw > cw + 2 && clipped.length < 10) {
              clipped.push(tag(el) + " cw=" + cw + " sw=" + sw + " ws=" + cs.whiteSpace + " | " + txt(el));
            }
            if (r.height > 50 && r.width < w.innerWidth * 0.99 && r.width > 150 && boxes.length < 8) {
              boxes.push(tag(el) + " w=" + Math.round(r.width) + " h=" + Math.round(r.height));
            }
          }
          boxes.sort(function(a, b){ return parseInt(b.split("w=")[1]) - parseInt(a.split("w=")[1]); });
          var vp = d.querySelector('meta[name=viewport]');
          var out = [
            "url=" + location.pathname,
            "vw=" + w.innerWidth + " vh=" + w.innerHeight + " dpr=" + w.devicePixelRatio,
            "scale=" + ((w.visualViewport || {}).scale || "-"),
            "viewport=" + (vp ? vp.content : "(none)"),
            "bodyW=" + b.scrollWidth + " docW=" + d.documentElement.scrollWidth,
            "zoom=" + (d.documentElement.style.zoom || "-"),
            "injected=" + !!w.__bizappInjected + " reflow=" + JSON.stringify(w.__bz_reflow || null),
            "iframes=" + d.querySelectorAll("iframe").length,
            "-- 最宽的溢出元素 --"
          ].concat(wide.length ? wide : ["(无)"]);
          out.push("-- 被裁剪的元素 --");
          out = out.concat(clipped.length ? clipped : ["(无)"]);
          out.push("-- 主要容器 --");
          out = out.concat(boxes.slice(0, 8));
          return out.join("\n");
        })()
        """#
        webView.evaluateJavaScript(js) { [weak self] result, error in
            guard let self = self else { return }
            var text = (result as? String) ?? ""
            if let err = error { text = "读取失败：" + err.localizedDescription + "\n" + text }
            let vc = UIActivityViewController(activityItems: [text], applicationActivities: nil)
            vc.popoverPresentationController?.barButtonItem = self.navigationItem.rightBarButtonItem
            self.present(vc, animated: true)
        }
    }

    // MARK: - 视图构建

    private func setupWebView() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        config.applicationNameForUserAgent = "BizApp/1.0"

        applyInjection(to: config.userContentController)

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

    /// 把注入样式挂到 WebView 配置上；开关变化后需要 reload 才生效
    private func applyInjection(to controller: WKUserContentController? = nil) {
        let cc = controller ?? webView.configuration.userContentController
        cc.removeAllUserScripts()
        guard webDark || centerPage || autoFit else { return }
        WebInjection.layoutWidth = layoutWidth
        WebInjection.autoFit = autoFit
        cc.addUserScript(WKUserScript(source: WebInjection.script(dark: webDark, fit: centerPage || autoFit),
                                      injectionTime: .atDocumentStart,
                                      forMainFrameOnly: false))
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

        let mark = Theme.label("MES系统", font: Theme.display(21), color: Theme.ink)
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
        webView.pageZoom = pageZoom
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

// MARK: - 网页注入

/// 老系统是按桌面 980px 排版的，在手机上被压成 0.38 倍：字小、框窄、上下大片留白。
/// 这里注入两层样式：
/// 1) 「反色 + 色相回正」把白底页面压到石墨底，大图二次反色保留原色；
/// 2) 「小页面适配」——内容明显小于屏幕时等比放大到占宽约 77%，并把内容提到屏幕上方，
///    对应设计目标：内容宽 77%、顶部留白 18%。
private enum WebInjection {

    /// 登录页：内容目标宽度占屏幕比例
    static let widthRatio: Double = 0.77
    /// 登录页：内容顶部留白占屏幕比例
    static let topRatio: Double = 0.165
    /// 登录页：放大幅度上限，避免低分辨率页被拉糊
    static let maxZoom: Double = 1.7
    /// 业务页：内容目标宽度占屏幕比例
    static let mobileRatio: Double = 0.95

    /// 布局宽度：0 = 跟随设备（device-width）；>0 = 强制按桌面宽度排版再整体缩放
    static var layoutWidth: Int = 0

    /// 是否把窄内容等比放大到铺满（带溢出自检，只放大不裁切）
    static var autoFit: Bool = true

    static func script(dark: Bool, fit: Bool) -> String {
        let flags = "{\"dark\": \(dark), \"fit\": \(fit), \"layoutWidth\": \(layoutWidth)}"
        return #"""
        (function () {
          if (window.__bizappInjected) { return; }
          window.__bizappInjected = true;

          var CFG = \#(flags);
          var WIDTH_RATIO = \#(widthRatio);
          var TOP_RATIO = \#(topRatio);
          var MAX_ZOOM = \#(maxZoom);
          var MOBILE_RATIO = \#(mobileRatio);

          // 登录页要"放大 + 上移"；业务页是另一套问题（桌面 980 视口被压扁），不能混着来
          var path = (location.pathname || '') + (location.search || '');
          var IS_LOGIN = /login/i.test(path);

          var DARK_CSS = [
            ':root{color-scheme:dark}',
            'html{background:#ffffff !important;filter:invert(.94) hue-rotate(180deg);-webkit-font-smoothing:antialiased}',
            'img.__bizapp_keep,video,canvas,object,embed{filter:invert(1) hue-rotate(180deg) !important}'
          ].join('');

          var LOGIN_CSS = [
            ':root{overflow-x:hidden !important}',
            'html.__bz_fit{overflow-x:hidden !important}',
            'html.__bz_fit body{height:auto !important;min-height:0 !important;overflow-x:hidden !important}'
          ].join('');

          // 业务页：老 ASP.NET 页面没有 viewport 声明，iOS 按 980px 排版再缩到 0.4 倍，
          // 于是字小、右边还空一大块。改成 device-width 让浏览器按真机宽度重排，
          // 宽表格改为整页横滑，而不是被裁掉。
          var MOBILE_CSS = [
            'html{-webkit-text-size-adjust:100% !important;overflow-x:auto !important}',
            'body{-webkit-text-size-adjust:100% !important;overflow-x:auto !important;min-width:0 !important;overflow-wrap:break-word !important;word-wrap:break-word !important}',
            'table{max-width:none !important}',
            'img{-webkit-user-drag:none}',
            'iframe,frame{max-width:100% !important}',
            '.__bz_center{margin-left:auto !important;margin-right:auto !important}'
          ].join('');

          function sheet(doc, css) {
            var root = doc.head || doc.documentElement;
            if (!root) { return false; }
            var s = doc.getElementById('__bizapp_style__');
            if (!s) {
              s = doc.createElement('style');
              s.id = '__bizapp_style__';
              root.appendChild(s);
            }
            if (s.textContent !== css) { s.textContent = css; }
            return true;
          }

          // 业务页专用：把 980 的虚拟视口改回真机宽度（改了才会重排，光调 zoom 是治标）
          function ensureViewport() {
            var head = document.head || document.documentElement;
            if (!head) { return; }
            var m = document.querySelector('meta[name="viewport"]');
            if (!m) {
              m = document.createElement('meta');
              m.setAttribute('name', 'viewport');
              head.appendChild(m);
            }
            var target = CFG.layoutWidth > 0 ? ('width=' + CFG.layoutWidth) : 'width=device-width';
            var c = m.getAttribute('content') || '';
            if (c.indexOf(target) < 0) {
              m.setAttribute('content', target + ', initial-scale=1, maximum-scale=5, user-scalable=yes');
            }
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

          // 量内容本身的尺寸：body 常被拉满屏，量它会永远"等于视口"
          function measure() {
            var body = document.body;
            if (!body) { return null; }
            var l = Infinity, t = Infinity, r = -Infinity, b = -Infinity, seen = false;
            for (var i = 0; i < body.children.length; i++) {
              var rc = body.children[i].getBoundingClientRect();
              if (rc.width < 1 && rc.height < 1) { continue; }
              l = Math.min(l, rc.left); t = Math.min(t, rc.top);
              r = Math.max(r, rc.right); b = Math.max(b, rc.bottom);
              seen = true;
            }
            return seen ? { w: r - l, h: b - t } : null;
          }

          // ── 登录页：等比放大到占宽 77%，再顶到屏幕上方 18% ──
          function fitLogin() {
            if (!CFG.fit || !document.body) { return; }

            var html = document.documentElement, body = document.body;
            var vv = window.visualViewport;
            var vh = vv ? vv.height : window.innerHeight;
            var vw = vv ? vv.width : window.innerWidth;

            // 键盘弹出时视口被压扁，此时重算会把页面缩回去。保持现状，让用户正常滚动。
            if (vv && (window.innerHeight - vv.height) > 120) { return; }

            html.classList.remove('__bz_fit');
            html.style.zoom = '';
            body.style.removeProperty('padding-top');

            var box = measure();
            if (!box || box.w < 40 || box.h < 40) { return; }

            // 长页面 / 满宽页面原样保留：放大会让表格横向溢出，反倒更难用
            if (box.h >= vh * 0.86 || box.w > vw * 0.96) { return; }

            var z = vw * WIDTH_RATIO / box.w;
            if (z > MAX_ZOOM) { z = MAX_ZOOM; }
            if (z < 1) { z = 1; }

            html.classList.add('__bz_fit');
            if (z > 1.01) { html.style.zoom = z; }

            // padding 会随 zoom 一起放大，所以这里按 z 折算，保证视觉留白恒为屏幕的 18%
            body.style.setProperty('padding-top', Math.round(vh * TOP_RATIO / z) + 'px', 'important');
          }

          // ── 业务页：按屏幕宽度重新排版（不是缩放）──
          // 前 13 版都在做"缩放"：页面按 980 排版再整体缩到 440，元素比例不变，
          // 于是按钮 80px 缩成 36pt、字 11px 缩成 4.9pt，放大回去就裁字，两头堵死。
          // v2.0 换成"重排"：把所有比屏幕宽的块改成 width:100%，让页面按屏幕重新流式布局；
          // 字号提到 15px、控件提到 42pt，触控和阅读一起解决。DOM 不动，提交照旧。
          function pxOf(v) { var n = parseFloat(v); return isNaN(n) ? 0 : n; }

          function reflowMobile() {
            var body = document.body;
            if (!body) { return; }
            var vw = document.documentElement.clientWidth || window.innerWidth;
            if (!vw) { return; }
            if (!CFG.autoFit) { return; }

            var tb = document.getElementsByTagName('table')[0];
            var wideTable = !!(tb && tb.getBoundingClientRect().width > vw * 1.15);

            // 宽表格页：列不多就压成屏幕宽（一屏看全），列多就保持横滑
            if (wideTable && tb && tb.rows && tb.rows[0]) {
              var cols = tb.rows[0].cells.length;
              if (cols > 0 && cols <= 5) {
                tb.style.setProperty('width', '100%', 'important');
                tb.style.setProperty('max-width', '100%', 'important');
                var cells = tb.querySelectorAll('th,td');
                for (var ci = 0; ci < cells.length; ci++) {
                  cells[ci].style.setProperty('width', 'auto', 'important');
                  cells[ci].style.setProperty('white-space', 'normal', 'important');
                  cells[ci].style.setProperty('word-break', 'break-all', 'important');
                  cells[ci].style.setProperty('font-size', '13px', 'important');
                }
                wideTable = false;
              }
            }

            // 1) 比屏幕宽的块一律改 100%，从外到内让页面按屏幕重排
            var nodes = body.getElementsByTagName('*');
            var n = Math.min(nodes.length, 2000);
            var fixed = 0;
            for (var i = 0; i < n; i++) {
              var el = nodes[i], tag = el.tagName;
              if (/^(SCRIPT|STYLE|LINK|BR|IMG|IFRAME|FRAME|TABLE|TR|TD|TH|TBODY|THEAD|OPTION|INPUT|BUTTON|SELECT|TEXTAREA)$/.test(tag)) { continue; }
              var cs = window.getComputedStyle(el);
              if (cs.display === 'inline' || cs.position === 'fixed') { continue; }
              if (pxOf(cs.width) > vw * 0.9) {
                el.style.setProperty('width', '100%', 'important');
                el.style.setProperty('max-width', '100%', 'important');
                el.style.setProperty('box-sizing', 'border-box', 'important');
                fixed++;
              }
            }

            // 2) 文字：11px 在手机上只有 11pt，提到 15px；宽表格页不动，免得列爆掉
            if (!wideTable) {
              var all = body.getElementsByTagName('*');
              for (var k = 0; k < Math.min(all.length, 1500); k++) {
                var e2 = all[k], t2 = e2.tagName;
                if (/^(SCRIPT|STYLE|INPUT|BUTTON|SELECT|TEXTAREA|TABLE|TR|TD|TH|IMG)$/.test(t2)) { continue; }
                if (e2.children.length > 4) { continue; }
                var fs = pxOf(window.getComputedStyle(e2).fontSize);
                if (fs > 0 && fs < 13) {
                  e2.style.setProperty('font-size', '15px', 'important');
                  e2.style.setProperty('line-height', '1.5', 'important');
                }
              }
            }

            // 3) 控件：40pt 以下的手指点不准，统一抬到 42pt
            var ctrls = body.querySelectorAll('input,select,textarea');
            for (var j = 0; j < ctrls.length; j++) {
              var c = ctrls[j];
              if ((c.type || '') === 'hidden') { continue; }
              c.style.setProperty('min-height', '42px', 'important');
              c.style.setProperty('font-size', '15px', 'important');
              c.style.setProperty('max-width', '100%', 'important');
              c.style.setProperty('box-sizing', 'border-box', 'important');
            }
            var btns = body.querySelectorAll('button,input[type=button],input[type=submit]');
            for (var b2 = 0; b2 < btns.length; b2++) {
              btns[b2].style.setProperty('min-height', '42px', 'important');
              btns[b2].style.setProperty('min-width', '64px', 'important');
              btns[b2].style.setProperty('padding', '8px 14px', 'important');
              btns[b2].style.setProperty('font-size', '14px', 'important');
              btns[b2].style.setProperty('box-sizing', 'border-box', 'important');
            }

            // 4) 一行挤四五个按钮时允许换行，别压成一条
            if (!wideTable) {
              var ps = body.querySelectorAll('div,td,p,span');
              for (var p2 = 0; p2 < Math.min(ps.length, 900); p2++) {
                var par = ps[p2];
                var nb = par.querySelectorAll(':scope > button, :scope > input[type=button], :scope > input[type=submit]').length;
                if (nb < 2) { continue; }
                var pr = par.getBoundingClientRect();
                if (pr.width < 60 || pr.width <= vw * 0.95) { continue; }
                par.style.setProperty('display', 'flex', 'important');
                par.style.setProperty('flex-wrap', 'wrap', 'important');
                par.style.setProperty('gap', '6px', 'important');
              }
            }

            // 5) 右上角浮层（用户名/订单信息）会压住按钮，给页面让出顶部空间
            var padTop = 0;
            var abs = body.getElementsByTagName('*');
            for (var a = 0; a < Math.min(abs.length, 1200); a++) {
              var ae = abs[a];
              var acs = window.getComputedStyle(ae);
              if (acs.position !== 'absolute' && acs.position !== 'fixed') { continue; }
              var ar = ae.getBoundingClientRect();
              if (ar.height < 12 || ar.top > 96 || ar.right < vw * 0.55) { continue; }
              if (ar.bottom + 8 > padTop) { padTop = ar.bottom + 8; }
            }
            if (padTop > 0 && padTop < 200) {
              body.style.setProperty('padding-top', Math.round(padTop) + 'px', 'important');
            }

            // 6) 仍被容器藏起来的文字：纯文本换行，控件行横向滑动
            var ds = body.getElementsByTagName('div');
            for (var q = 0; q < Math.min(ds.length, 900); q++) {
              var d2 = ds[q];
              if (!d2.textContent || d2.textContent.replace(/\s/g, '').length < 6) { continue; }
              var cs2 = window.getComputedStyle(d2);
              if (cs2.overflowX !== 'hidden' && cs2.whiteSpace !== 'nowrap') { continue; }
              var cw = d2.clientWidth, sw = d2.scrollWidth;
              if (cw < 40 || sw <= cw + 2 || sw > cw * 2.2) { continue; }
              if (d2.children.length === 0) {
                d2.style.setProperty('white-space', 'normal', 'important');
                d2.style.setProperty('overflow', 'visible', 'important');
              } else {
                d2.style.setProperty('overflow-x', 'auto', 'important');
              }
            }

            window.__bz_reflow = { vw: vw, fixed: fixed, wideTable: wideTable };
          }

          // Opcenter 这类系统满屏 iframe / frameset，主文档 body 可能是空的，必须钻进去
          function deepInject(doc, depth) {
            if (depth > 3) { return; }
            var nodes;
            try { nodes = doc.querySelectorAll('iframe,frame'); } catch (e) { return; }
            for (var i = 0; i < nodes.length; i++) {
              var idoc = null;
              try { idoc = nodes[i].contentDocument; } catch (e) { idoc = null; }
              if (!idoc || !idoc.documentElement) { continue; }   // 跨域就交给 WKUserScript
              try {
                sheet(idoc, CFG.dark ? DARK_CSS + MOBILE_CSS : MOBILE_CSS);
                idoc.documentElement.style.overflowX = 'auto';
                if (idoc.body) { idoc.body.style.overflowX = 'auto'; }
              } catch (e) {}
              deepInject(idoc, depth + 1);
            }
          }

          function run() {
            try { body_of_run(); } catch (e) {}
          }

          function body_of_run() {
            if (IS_LOGIN) {
              sheet(document, (CFG.dark ? DARK_CSS : '') + (CFG.fit ? LOGIN_CSS : ''));
              fitLogin();
            } else {
              ensureViewport();
              sheet(document, (CFG.dark ? DARK_CSS : '') + (CFG.fit ? MOBILE_CSS : ''));
              reflowMobile();
              deepInject(document, 1);
            }
            keepColor();
          }

          document.addEventListener('DOMContentLoaded', run);
          run();
          window.addEventListener('load', function () {
            run();
            setTimeout(run, 300);
            setTimeout(run, 1000);
          });
          // 滚动时 iOS 会反复触发 resize，防抖一下，别每次都遍历 DOM
          var rzTimer = null;
          window.addEventListener('resize', function () {
            if (rzTimer) { clearTimeout(rzTimer); }
            rzTimer = setTimeout(run, 220);
          });
        })();
        """#
    }
}
