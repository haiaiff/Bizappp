import UIKit
import WebKit

/// 单页 WKWebView 壳：把内网 ASP.NET 站点包装成原生 iOS App
final class WebViewController: UIViewController {

    // MARK: - 配置

    /// 默认入口地址（App 内可修改并记住）
    private let defaultServer = "http://10.219.62.32:49919/Login.aspx"
    private static let serverKey = "bizapp.serverURL"

    private let brand = UIColor(red: 26 / 255, green: 109 / 255, blue: 217 / 255, alpha: 1)

    private var serverURL: String {
        get { UserDefaults.standard.string(forKey: WebViewController.serverKey) ?? defaultServer }
        set { UserDefaults.standard.set(newValue, forKey: WebViewController.serverKey) }
    }

    // MARK: - 视图

    private var webView: WKWebView!
    private let progressBar = UIProgressView(progressViewStyle: .bar)
    private let errorView = UIView()
    private let errorLabel = UILabel()
    private var progressObservation: NSKeyValueObservation?
    private var titleObservation: NSKeyValueObservation?

    private var lastDownloadURL: URL?

    // MARK: - 生命周期

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(white: 0.96, alpha: 1)
        setupWebView()
        setupChrome()
        setupErrorView()
        load()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    // MARK: - 构建

    private func setupWebView() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        config.applicationNameForUserAgent = "BizApp/1.0"

        webView = WKWebView(frame: .zero, configuration: config)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.keyboardDismissMode = .interactive
        webView.scrollView.contentInsetAdjustmentBehavior = .automatic
        webView.isOpaque = true
        webView.backgroundColor = .white

        let refresh = UIRefreshControl()
        refresh.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        webView.scrollView.refreshControl = refresh

        view.addSubview(webView)

        progressBar.translatesAutoresizingMaskIntoConstraints = false
        progressBar.progressTintColor = brand
        progressBar.trackTintColor = .clear
        progressBar.progress = 0
        progressBar.isHidden = true
        view.addSubview(progressBar)

        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            progressBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            progressBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progressBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            progressBar.heightAnchor.constraint(equalToConstant: 2)
        ])

        progressObservation = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] webView, _ in
            let progress = Float(webView.estimatedProgress)
            self?.progressBar.setProgress(progress, animated: true)
            self?.progressBar.isHidden = progress >= 1.0
        }

        titleObservation = webView.observe(\.title, options: [.new]) { [weak self] webView, _ in
            self?.navigationItem.title = webView.title?.isEmpty == false ? webView.title : "业务系统"
        }
    }

    private func setupChrome() {
        navigationItem.title = "业务系统"

        let back = UIBarButtonItem(image: UIImage(systemName: "chevron.backward"),
                                   style: .plain, target: self, action: #selector(goBack))
        back.isEnabled = false
        navigationItem.leftBarButtonItem = back

        let more = UIBarButtonItem(image: UIImage(systemName: "ellipsis.circle"),
                                   style: .plain, target: self, action: #selector(showMore))
        navigationItem.rightBarButtonItem = more
    }

    private func setupErrorView() {
        errorView.translatesAutoresizingMaskIntoConstraints = false
        errorView.backgroundColor = UIColor(white: 0.96, alpha: 1)
        errorView.isHidden = true
        view.addSubview(errorView)

        let icon = UILabel()
        icon.text = "!"
        icon.font = .boldSystemFont(ofSize: 34)
        icon.textColor = brand
        icon.textAlignment = .center
        icon.backgroundColor = UIColor(red: 232 / 255, green: 240 / 255, blue: 252 / 255, alpha: 1)
        icon.layer.cornerRadius = 32
        icon.layer.borderWidth = 2
        icon.layer.borderColor = brand.cgColor
        icon.clipsToBounds = true
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 64).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 64).isActive = true

        let title = UILabel()
        title.text = "无法连接服务器"
        title.font = .boldSystemFont(ofSize: 17)
        title.textColor = UIColor(white: 0.12, alpha: 1)
        title.textAlignment = .center

        errorLabel.numberOfLines = 0
        errorLabel.textAlignment = .center
        errorLabel.font = .systemFont(ofSize: 13)
        errorLabel.textColor = UIColor(white: 0.42, alpha: 1)

        let retry = makeButton(title: "重新加载", filled: true, action: #selector(handleRetry))
        let change = makeButton(title: "修改服务器地址", filled: false, action: #selector(showServerDialog))

        let iconRow = UIView()
        iconRow.translatesAutoresizingMaskIntoConstraints = false
        iconRow.addSubview(icon)
        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: iconRow.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: iconRow.centerYAnchor),
            iconRow.heightAnchor.constraint(equalToConstant: 64)
        ])

        let stack = UIStackView(arrangedSubviews: [iconRow, title, errorLabel, retry, change])
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 14
        stack.setCustomSpacing(24, after: errorLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false
        errorView.addSubview(stack)

        NSLayoutConstraint.activate([
            errorView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            errorView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            errorView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            errorView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stack.centerYAnchor.constraint(equalTo: errorView.centerYAnchor, constant: -30),
            stack.leadingAnchor.constraint(equalTo: errorView.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(equalTo: errorView.trailingAnchor, constant: -32),

            retry.widthAnchor.constraint(equalTo: stack.widthAnchor),
            retry.heightAnchor.constraint(equalToConstant: 46),
            change.widthAnchor.constraint(equalTo: stack.widthAnchor),
            change.heightAnchor.constraint(equalToConstant: 46)
        ])
    }

    private func makeButton(title: String, filled: Bool, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 15, weight: .medium)
        button.layer.cornerRadius = 10
        if filled {
            button.backgroundColor = brand
            button.setTitleColor(.white, for: .normal)
        } else {
            button.backgroundColor = .white
            button.setTitleColor(brand, for: .normal)
            button.layer.borderWidth = 1
            button.layer.borderColor = brand.cgColor
        }
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    // MARK: - 加载

    private func load() {
        guard let url = URL(string: serverURL) else { return }
        webView.load(URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 25))
    }

    @objc private func handleRefresh() {
        if webView.url == nil {
            load()
        } else {
            webView.reload()
        }
    }

    @objc private func handleRetry() {
        hideError()
        webView.stopLoading()
        if webView.url == nil {
            load()
        } else {
            webView.reload()
        }
    }

    @objc private func goBack() {
        if webView.canGoBack {
            webView.goBack()
        }
    }

    @objc private func showMore() {
        let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "刷新", style: .default) { [weak self] _ in
            self?.handleRefresh()
        })
        sheet.addAction(UIAlertAction(title: "回到首页", style: .default) { [weak self] _ in
            self?.load()
        })
        sheet.addAction(UIAlertAction(title: "在 Safari 中打开", style: .default) { [weak self] _ in
            guard let self = self, let url = URL(string: self.serverURL) else { return }
            UIApplication.shared.open(url)
        })
        sheet.addAction(UIAlertAction(title: "修改服务器地址", style: .default) { [weak self] _ in
            self?.showServerDialog()
        })
        sheet.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(sheet, animated: true)
    }

    @objc private func showServerDialog() {
        let alert = UIAlertController(title: "服务器地址",
                                      message: "填写登录页地址，例如 http://10.219.62.32:49919/Login.aspx",
                                      preferredStyle: .alert)
        alert.addTextField { field in
            field.text = self.serverURL
            field.keyboardType = .URL
            field.autocapitalizationType = .none
            field.autocorrectionType = .no
        }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "保存并加载", style: .default) { [weak self, weak alert] _ in
            guard let self = self, let text = alert?.textFields?.first?.text else { return }
            var value = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if value.isEmpty { return }
            if !value.lowercased().hasPrefix("http://") && !value.lowercased().hasPrefix("https://") {
                value = "http://" + value
            }
            self.serverURL = value
            self.hideError()
            self.load()
        })
        present(alert, animated: true)
    }

    // MARK: - 状态

    private func showError(_ detail: String) {
        progressBar.isHidden = true
        errorLabel.text = "\(detail)\n\n服务器：\(serverURL)"
        errorView.isHidden = false
        webView.scrollView.refreshControl?.endRefreshing()
    }

    private func hideError() {
        errorView.isHidden = true
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
        let code = (error as NSError).code
        switch code {
        case NSURLErrorCannotFindHost:
            return "找不到服务器地址，请确认已连接公司内网。"
        case NSURLErrorCannotConnectToHost:
            return "连接服务器失败，服务可能未启动或端口不可达。"
        case NSURLErrorTimedOut:
            return "连接超时，网络较慢或服务器无响应。"
        case NSURLErrorNotConnectedToInternet:
            return "当前设备未连接网络，请先连接内网 Wi-Fi。"
        default:
            return "加载失败：\((error as NSError).localizedDescription)"
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
        progressBar.isHidden = false
        hideError()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        progressBar.isHidden = true
        updateBackButton()
        webView.scrollView.refreshControl?.endRefreshing()
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
