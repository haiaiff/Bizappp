import UIKit

/// 服务器地址设置页（卡片式弹出，替代原来的系统 Alert）
final class ServerSettingsViewController: UIViewController, UITextFieldDelegate {

    var onSave: ((String) -> Void)?

    private let initialValue: String
    private let scrollView = UIScrollView()
    private let fieldBox = UIView()
    private let textField = UITextField()
    private let saveButton = PressableButton(type: .custom)

    init(current: String) {
        self.initialValue = current
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.sheet
        setupNavigation()
        buildContent()
        observeKeyboard()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        textField.becomeFirstResponder()
    }

    private func setupNavigation() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = Theme.sheet
        appearance.shadowColor = .clear
        appearance.titleTextAttributes = [
            .foregroundColor: Theme.ink,
            .font: Theme.body(15, medium: true)
        ]
        navigationItem.standardAppearance = appearance
        navigationItem.scrollEdgeAppearance = appearance
        navigationItem.title = "服务器"

        let cancel = UIBarButtonItem(title: "取消", style: .plain, target: self, action: #selector(cancelTapped))
        cancel.setTitleTextAttributes([.font: Theme.body(15), .foregroundColor: Theme.ink60], for: .normal)
        navigationItem.leftBarButtonItem = cancel

        let save = UIBarButtonItem(title: "保存", style: .done, target: self, action: #selector(saveTapped))
        save.setTitleTextAttributes([.font: Theme.body(15, medium: true), .foregroundColor: Theme.accent], for: .normal)
        navigationItem.rightBarButtonItem = save
    }

    private func buildContent() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.keyboardDismissMode = .interactive
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)

        let eybrow = Theme.label("SERVER  ADDRESS", font: Theme.micro(10.5), color: Theme.accent)
        eybrow.attributedText = Theme.tracked("SERVER  ADDRESS", spacing: 1.8)

        let title = Theme.label("登录页地址", font: Theme.display(24), color: Theme.ink)
        let caption = Theme.label("填系统入口页，需要设备能连到公司内网。",
                                  font: Theme.body(13), color: Theme.ink60)

        fieldBox.backgroundColor = Theme.surface
        fieldBox.layer.cornerRadius = Theme.radius
        fieldBox.layer.borderWidth = 1
        fieldBox.layer.borderColor = Theme.line.cgColor
        fieldBox.translatesAutoresizingMaskIntoConstraints = false

        textField.text = initialValue
        textField.font = Theme.mono(12.5)
        textField.textColor = Theme.ink
        textField.tintColor = Theme.accent
        textField.keyboardType = .URL
        textField.keyboardAppearance = Theme.appearance == .light ? .light : .dark
        textField.autocapitalizationType = .none
        textField.autocorrectionType = .no
        textField.spellCheckingType = .no
        textField.clearButtonMode = .whileEditing
        textField.delegate = self
        textField.translatesAutoresizingMaskIntoConstraints = false
        fieldBox.addSubview(textField)

        let example = Theme.label("例：http://10.219.62.32:49919/Login.aspx",
                                  font: Theme.mono(11), color: Theme.ink35)

        saveButton.setTitle("保存并重新加载", for: .normal)
        saveButton.setTitleColor(Theme.onInk, for: .normal)
        saveButton.titleLabel?.font = Theme.body(15, medium: true)
        saveButton.backgroundColor = Theme.ink
        saveButton.layer.cornerRadius = Theme.radius
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)

        let footnote = Theme.label("地址仅保存在这台手机上，卸载应用后会被清除。",
                                   font: Theme.body(12), color: Theme.ink35)

        let stack = UIStackView(arrangedSubviews: [eybrow, title, caption, fieldBox, example, saveButton, footnote])
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 0
        stack.setCustomSpacing(14, after: eybrow)
        stack.setCustomSpacing(8, after: title)
        stack.setCustomSpacing(22, after: caption)
        stack.setCustomSpacing(8, after: fieldBox)
        stack.setCustomSpacing(28, after: example)
        stack.setCustomSpacing(18, after: saveButton)
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 22),
            stack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: Theme.gutter),
            stack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -Theme.gutter),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -32),

            fieldBox.heightAnchor.constraint(equalToConstant: 52),
            textField.leadingAnchor.constraint(equalTo: fieldBox.leadingAnchor, constant: 14),
            textField.trailingAnchor.constraint(equalTo: fieldBox.trailingAnchor, constant: -12),
            textField.centerYAnchor.constraint(equalTo: fieldBox.centerYAnchor),
            saveButton.heightAnchor.constraint(equalToConstant: 52)
        ])
    }

    // MARK: - 交互

    @objc private func cancelTapped() {
        view.endEditing(true)
        dismiss(animated: true)
    }

    @objc private func saveTapped() {
        guard var value = textField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            shake()
            return
        }
        let lower = value.lowercased()
        if !lower.hasPrefix("http://") && !lower.hasPrefix("https://") {
            value = "http://" + value
        }
        saveButton.haptic()
        view.endEditing(true)
        onSave?(value)
        dismiss(animated: true)
    }

    private func shake() {
        let anim = CAKeyframeAnimation(keyPath: "transform.translation.x")
        anim.values = [-8, 8, -5, 5, 0]
        anim.duration = 0.32
        fieldBox.layer.add(anim, forKey: "shake")
        fieldBox.layer.borderColor = Theme.danger.cgColor
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        fieldBox.layer.borderColor = Theme.accent.cgColor
        fieldBox.layer.borderWidth = 1.5
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        fieldBox.layer.borderColor = Theme.line.cgColor
        fieldBox.layer.borderWidth = 1
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        saveTapped()
        return true
    }

    // MARK: - 键盘

    private func observeKeyboard() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardFrameChanged(_:)),
                                               name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardHidden),
                                               name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    @objc private func keyboardFrameChanged(_ note: Notification) {
        guard let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        let overlap = max(0, view.bounds.maxY - view.convert(frame, from: nil).minY)
        scrollView.contentInset.bottom = overlap
        scrollView.verticalScrollIndicatorInsets.bottom = overlap
    }

    @objc private func keyboardHidden() {
        scrollView.contentInset.bottom = 0
        scrollView.verticalScrollIndicatorInsets.bottom = 0
    }
}
