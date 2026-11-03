import UIKit

/// 设计令牌：颜色 / 字体 / 间距统一在这里，避免散落
///
/// 暗色是主设计（中性石墨底 + 单一信号蓝），浅色是同一套令牌的反向映射。
/// 暗色的中性值刻意不带色相：网页内容反色后必然是中性灰，外壳只要偏一点蓝就会露出接缝。
/// 两套值都写在 token 里，视图层只认语义名，不出现任何字面色值。
enum Theme {

    // MARK: 色彩（暗：石墨 / 浅：纸）

    /// 页面底色
    static let paper    = dyn(dark: 0x0F0F0F, light: 0xF3F3F1)
    /// 弹层底色（比页面略抬一级）
    static let sheet    = dyn(dark: 0x151515, light: 0xF7F7F5)
    /// 卡片 / 输入框
    static let surface  = dyn(dark: 0x1B1B1B, light: 0xFFFFFF)
    /// 1px 硬边分割线
    static let line     = dyn(dark: 0x2B2B2B, light: 0xE2E2DD)

    /// 主文字
    static let ink      = dyn(dark: 0xECECEC, light: 0x101318)
    /// 次级文字
    static let ink60    = dyn(dark: 0x9C9C9C, light: 0x5A6270)
    /// 三级文字（提示 / 脚注），仍保持 4.5:1 以上
    static let ink35    = dyn(dark: 0x7D7D7D, light: 0x949BA5)
    /// 主按钮上的文字（与 ink 互为反色）
    static let onInk    = dyn(dark: 0x0F0F0F, light: 0xF7F7F5)

    /// 信号色：只用于进度、眉标、链接
    static let accent   = dyn(dark: 0x5B9BF5, light: 0x1257C7)
    static let accentSoft = dyn(dark: 0x161C26, light: 0xE9EFFB)
    /// 出错提示
    static let danger   = dyn(dark: 0xE0705F, light: 0xC0392B)

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

// MARK: - 明暗

extension Theme {

    enum Appearance: String, CaseIterable {
        case dark, light, system

        var title: String {
            switch self {
            case .dark:   return "深色"
            case .light:  return "浅色"
            case .system: return "跟随系统"
            }
        }

        var style: UIUserInterfaceStyle {
            switch self {
            case .dark:   return .dark
            case .light:  return .light
            case .system: return .unspecified
            }
        }
    }

    private static let appearanceKey = "bizapp.appearance"

    /// 默认深色：这是为暗环境 / 长时间盯屏设计的主形态
    static var appearance: Appearance {
        get { Appearance(rawValue: UserDefaults.standard.string(forKey: appearanceKey) ?? "") ?? .dark }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: appearanceKey) }
    }

    /// 外观变更后的回调，由 AppDelegate 挂载（重建根控制器，让动态色整体生效）
    static var onChange: (() -> Void)?

    static func setAppearance(_ value: Appearance) {
        guard value != appearance else { return }
        appearance = value
        onChange?()
    }

    /// 把当前外观套到所有窗口上
    static func apply(to window: UIWindow?) {
        window?.overrideUserInterfaceStyle = appearance.style
        window?.backgroundColor = paper
    }
}

// MARK: - 基础件

private func dyn(dark: UInt32, light: UInt32) -> UIColor {
    UIColor(dynamicProvider: { traits in
        traits.userInterfaceStyle == .dark ? UIColor(rgb: dark) : UIColor(rgb: light)
    })
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
