import UIKit

/// 断网 / 加载失败的整页状态：左对齐排版，不居中，留白克制
final class ErrorStateView: UIView {

    var onRetry: (() -> Void)?
    var onSettings: (() -> Void)?

    private let eyebrowDot = UIView()
    private let eyebrow = UILabel()
    private let titleLabel = Theme.label("连不上服务器", font: Theme.display(26), color: Theme.ink)
    private let bodyLabel = Theme.label("", font: Theme.body(14), color: Theme.ink60)
    private let urlBox = UIView()
    private let urlLabel = Theme.label("", font: Theme.mono(12), color: Theme.ink60)
    private let primary = PressableButton(type: .custom)
    private let secondary = PressableButton(type: .custom)
    private let hint = Theme.label("确认已连接公司内网 Wi-Fi 后重试", font: Theme.body(12), color: Theme.ink35)

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = Theme.paper
        build()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func build() {
        eyebrowDot.backgroundColor = Theme.accent
        eyebrowDot.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            eyebrowDot.widthAnchor.constraint(equalToConstant: 7),
            eyebrowDot.heightAnchor.constraint(equalToConstant: 7)
        ])

        eyebrow.font = Theme.micro(10.5)
        eyebrow.textColor = Theme.accent
        eyebrow.attributedText = Theme.tracked("NO  CONNECTION", spacing: 1.8)

        let eyebrowRow = UIStackView(arrangedSubviews: [eyebrowDot, eyebrow])
        eyebrowRow.axis = .horizontal
        eyebrowRow.alignment = .center
        eyebrowRow.spacing = 8

        bodyLabel.textColor = Theme.ink60
        titleLabel.numberOfLines = 2

        urlBox.backgroundColor = Theme.surface
        urlBox.layer.cornerRadius = Theme.radius
        urlBox.layer.borderWidth = 1
        urlBox.layer.borderColor = Theme.line.cgColor

        urlLabel.numberOfLines = 2
        urlLabel.lineBreakMode = .byCharWrapping
        urlLabel.translatesAutoresizingMaskIntoConstraints = false
        urlBox.addSubview(urlLabel)
        NSLayoutConstraint.activate([
            urlLabel.topAnchor.constraint(equalTo: urlBox.topAnchor, constant: 13),
            urlLabel.bottomAnchor.constraint(equalTo: urlBox.bottomAnchor, constant: -13),
            urlLabel.leadingAnchor.constraint(equalTo: urlBox.leadingAnchor, constant: 14),
            urlLabel.trailingAnchor.constraint(equalTo: urlBox.trailingAnchor, constant: -14)
        ])

        primary.setTitle("重新加载", for: .normal)
        primary.setTitleColor(Theme.surface, for: .normal)
        primary.titleLabel?.font = Theme.body(15, medium: true)
        primary.backgroundColor = Theme.ink
        primary.layer.cornerRadius = Theme.radius
        primary.addTarget(self, action: #selector(tapRetry), for: .touchUpInside)

        secondary.setTitle("更换服务器地址", for: .normal)
        secondary.setTitleColor(Theme.accent, for: .normal)
        secondary.titleLabel?.font = Theme.body(14, medium: true)
        secondary.contentHorizontalAlignment = .left
        secondary.addTarget(self, action: #selector(tapSettings), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [eyebrowRow, titleLabel, bodyLabel, urlBox, primary, secondary, hint])
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 0
        stack.setCustomSpacing(18, after: eyebrowRow)
        stack.setCustomSpacing(10, after: titleLabel)
        stack.setCustomSpacing(22, after: bodyLabel)
        stack.setCustomSpacing(30, after: urlBox)
        stack.setCustomSpacing(6, after: primary)
        stack.setCustomSpacing(26, after: secondary)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 64),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Theme.gutter),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Theme.gutter),
            primary.heightAnchor.constraint(equalToConstant: 52),
            secondary.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    func configure(message: String, server: String) {
        bodyLabel.text = message
        urlLabel.text = server
    }

    @objc private func tapRetry() {
        primary.haptic()
        onRetry?()
    }

    @objc private func tapSettings() {
        secondary.haptic()
        onSettings?()
    }
}
