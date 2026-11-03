import UIKit

/// 设计令牌：颜色 / 字体 / 间距统一在这里，避免散落
enum Theme {

    // MARK: 色彩（墨 + 纸 + 单一强调色）
    static let ink        = UIColor(rgb: 0x101318)
    static let ink60      = UIColor(rgb: 0x5A6270)
    static let ink35      = UIColor(rgb: 0x9AA1AC)
    static let paper      = UIColor(rgb: 0xF3F3F1)
    static let surface    = UIColor(rgb: 0xFFFFFF)
    static let line       = UIColor(rgb: 0xE2E2DD)
    static let accent     = UIColor(rgb: 0x1257C7)
    static let accentSoft = UIColor(rgb: 0xE9EFFB)

    // MARK: 间距
    static let gutter: CGFloat = 24
    static let radius: CGFloat = 4

    // MARK: 字体
    /// 中文标题：苹方 Semibold（系统中文字形最稳，无需内置字体文件）
    static func display(_ size: CGFloat) -> UIFont {
        UIFont(name: "PingFangSC-Semibold", size: size) ?? .systemFont(ofSize: size, weight: .semibold)
    }

    /// 中文正文
    static func body(_ size: CGFloat, medium: Bool = false) -> UIFont {
        let name = medium ? "PingFangSC-Medium" : "PingFangSC-Regular"
        return UIFont(name: name, size: size) ?? .systemFont(ofSize: size, weight: medium ? .medium : .regular)
    }

    /// 拉丁小标签：Avenir Next（iOS 内置，字形比系统默认更有编辑感）
    static func micro(_ size: CGFloat = 11) -> UIFont {
        UIFont(name: "AvenirNext-DemiBold", size: size) ?? .systemFont(ofSize: size, weight: .semibold)
    }

    /// 地址等代码信息
    static func mono(_ size: CGFloat = 12) -> UIFont {
        UIFont(name: "Menlo-Regular", size: size) ?? .monospacedSystemFont(ofSize: size, weight: .regular)
    }

    // MARK: 小工具
    static func label(_ text: String, font: UIFont, color: UIColor) -> UILabel {
        let l = UILabel()
        l.text = text
        l.font = font
        l.textColor = color
        l.numberOfLines = 0
        return l
    }

    /// 字间距（用于全大写小标签）
    static func tracked(_ text: String, spacing: CGFloat) -> NSAttributedString {
        NSAttributedString(string: text, attributes: [.kern: spacing])
    }
}

extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(red: CGFloat((rgb >> 16) & 0xFF) / 255,
                  green: CGFloat((rgb >> 8) & 0xFF) / 255,
                  blue: CGFloat(rgb & 0xFF) / 255,
                  alpha: 1)
    }
}

/// 带轻微按压反馈的按钮（触感 + 缩放，比系统默认按钮更有质感）
class PressableButton: UIButton {

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.16, delay: 0, options: [.beginFromCurrentState, .allowUserInteraction]) {
                self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.975, y: 0.975) : .identity
                self.alpha = self.isHighlighted ? 0.86 : 1
            }
        }
    }

    func haptic() {
        let gen = UIImpactFeedbackGenerator(style: .light)
        gen.impactOccurred()
    }
}
